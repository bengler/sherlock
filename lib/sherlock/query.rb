
# Builds a chunk of JSON based on the query parameters, which can be passed to elasticsearch.

module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order, :min, :max, :deprecated_range, :fields, :accessible_paths, :uid_query, :tags_query, :deleted, :return_fields
    def initialize(options, accessible_paths = [])
      options.symbolize_keys!
      @search_term = options[:q]
      @limit = options.fetch(:limit) { 10 }
      @offset = options.fetch(:offset) { 0 }
      @uid = options[:uid] || '*:*'
      @sort_attribute = options[:sort_by]
      @order = Query.normalize_sort_order(options[:order])
      @min = options[:min]
      @max = options[:max]
      @deprecated_range = options[:range]
      @fields = options.fetch(:fields) {[]}
      @accessible_paths = accessible_paths
      @uid_query = Pebbles::Uid.query(uid, :species => 'klass', :path => 'label', :suffix => '')
      @tags_query = options[:tags]
      @deleted = options[:deleted]
      @return_fields = options[:return_fields]
    end


    def to_hash
      result = sort.merge(
        { :from => offset.to_i, # 'from' _has_ to be at the beginning of the json blotch
          :size => limit.to_i,  # 'size' can be wherever, but hey, why not let it keep 'from' company?
          :query => {
            :bool => bool_query
          }
        }
      )
      result['_source'] = compile_return_fields if return_fields

      if tags_queries
        tags_queries.each do |rk,rv|
          unless rv.empty?
            result[:filter] ||= {}
            result[:filter][rk] ||= []
            result[:filter][rk] << rv
            result[:filter][rk] << security_filter if security_filter
            result[:filter][rk] << missing_filter if missing_filter
            result[:filter][rk] << exists_filter if exists_filter
            result[:filter][rk].flatten!
          end
        end
      end
      unless result[:filter]
        filter = filters
        result[:filter] = filter if filter
      end
      result
    end


    def filters
      result = []
      result << path_or_query if path_or_query
      result << security_filter

      missing = missing_filter
      result << missing if missing

      exists = exists_filter
      result << exists if exists

      return {:and => result} if result.count > 1
      return result.first if result.count == 1
      return nil
    end


    def bool_query
      queries = []
      queries << query_string if search_term
      queries = queries + uid_field_queries
      queries = queries + field_queries
      queries = queries << deprecated_range_query if deprecated_range
      queries = queries + range_query if (min || max)
      {:must => queries}
    end

    # typically *:apdm.oa|rb.* returns
    # {:or=>[{:term=>{"label_1_"=>"oa"}}, {:term=>{"label_1_"=>"rb"}}]}
    def path_or_query
      return nil if uid_query.list?
      filter = {}
      uid_query.to_hash.map do |key, value|
        if value.is_a?(Array)
          filter[:or] ||= []
          value.each do |v|
            filter[:or] << {:term => {key.to_s => v}}
          end
        end
      end
      return filter if filter[:or]
      nil
    end


    def query_string
      { :query_string => {
          :query => sanitize_string_for_elasticsearch_string_query(search_term.downcase),
          :default_operator => 'AND'
        }
      }
    end

    def uid_field_queries
      if uid_query.list? # e.g. *:apdm.rb.*$1643364|1637855
        oids = uid_query.terms.map { |term| Pebbles::Uid.query(term).oid }.compact
        return [{:terms => {'oid_' => oids}}]
      else
        # e.g. *:apdm.rb.*
        result = uid_query.to_hash.map do |key, value|
          {:term => {key.to_s => value}} unless value.is_a?(Array)
        end
        result.compact
      end
    end

    def tags_queries
      return nil unless @tags_query
      results = {}
      results[:and] = []
      results[:or] = []
      results[:not] = []
      if @tags_query.include?(",")
        terms = @tags_query.split(",").map{|tag| tag.strip}
        results[:and] << terms.map{|t| {"term" => {"tags_vector" => t}}}
      else
        ands = @tags_query.split('&')
        ands.each do |a|
          if a.strip[0] != "!"
            if a.index("|")
              a.split("|").each do |o|
                o = o.gsub("(", "").strip
                  o = o.gsub(")", "").strip
                results[:or] << {
                  "term" => { "tags_vector" => o.strip}
                }
              end
            else
              results[:and] << {
                "term" => { "tags_vector" => a.strip}
              }
            end
          else
            results[:and] << {
              "not" => { "term" => { "tags_vector" => a.gsub("!", "").strip} }
            }
          end
        end
      end
      results
    end

    # query on specific field value
    def field_queries
      result = []
      fields.each do |key, value|
        if value != 'null' && value != '!null'
          if value.match(/\|/) # A value containing a pipe will be parsed as an OR statement
            result << {:terms => {key => value.downcase.split('|')}}
          else
            result << {:term => {key => value.downcase}}
          end
        end
      end
      result
    end


    def missing_filter
      missing_fields = []

      # Fields specified by client which must be missing
      fields.each do |key, value|
        missing_fields << {:missing => {:field => key, :existence => true, :null_value => true}} if value == 'null'
      end

      # Implicit missing label field because of uid search
      unless uid_query.path =~ /\*$/
        missing_fields << {:missing => {:field => uid_query.next_path_label}}
      end

      return {:and => missing_fields} if missing_fields.count > 1
      return missing_fields.first if missing_fields.count == 1
      nil
    end

    def exists_filter
      exists_fields = []
      fields.each do |key, value|
        exists_fields << {:exists => {:field => key}} if value == '!null'
      end
      return {:and => exists_fields} if exists_fields.count > 1
      return exists_fields.first if exists_fields.count == 1
      nil
    end

    def range_query
      ranges = []

      min.each do |attribute, value|
        ranges << {:range => {attribute => {'gte' => value}}}
      end if min

      max.each do |attribute, value|
        ranges << {:range => {attribute => {'lte' => value}}}
      end if max

      ranges
    end


    def deprecated_range_query
      params = {}
      params['lte'] = deprecated_range['to'] if deprecated_range['to']
      params['gte'] = deprecated_range['from'] if deprecated_range['from']
      {:range => {deprecated_range['attribute'] => params}}
    end


    def security_filter
      return {:and => [{:term => {'restricted' => false}}, {:not => {:term => {'deleted' => true}}}]} if accessible_paths.empty?
      access_requirements = []
      accessible_paths.each do |path|
        requirement_set = []
        Pebbles::Uid::Labels.new(path, :name => 'label', :suffix => '').to_hash.each do |key, value|
          requirement_set << {:term => {key.to_s => value}}
        end
        if deleted == 'only'
          # explicitly only include deleted records
          requirement_set << {:term => {'deleted' => true}}
        elsif deleted == 'include'
          # no extra filter -> include all
        else
          # explicitly exclude deleted records
          requirement_set << {:not => {:term => {'deleted' => true}}}
        end
        access_requirements << {:and => requirement_set}
      end

      non_access_requirements = [{:term => {"restricted" => false}}]
      if deleted == 'only'
        non_access_requirements << {:term =>{'deleted' => true}}
      else
        non_access_requirements << {:not => {:term => {'deleted' => true}}}
      end
      access_requirements << { :and => non_access_requirements}
      {:or => access_requirements}
    end

    def sort
      return {} unless sort_attribute
      if sort_attribute.match(",")
        attributes = sort_attribute.split(",").map{|attr| attr.strip}
        h = {:sort => []}
        attributes.each_with_index do |attr, i|
          h[:sort] << { attr => {'order' => (order[i] || order[0]), 'ignore_unmapped' => true} }
        end
        h[:sort] << '_score'
        h
      else
        {:sort => [{ sort_attribute => {'order' => order.first, 'ignore_unmapped' => true} }, '_score']}
      end
    end

    def self.normalize_sort_order(order)
      order ||= "desc"
      if order.match(",")
        orders = order.split(",").map{|o| o.strip}
      else
        orders = [order]
      end
      result = []
      orders.each do |order|
        if order.try(:downcase) == 'asc'
          result << 'asc'
        else
          result << 'desc'
        end
      end
      result
    end

    # called by Sherlock::Elasticsearch.query
    def to_json
      to_hash.to_json
    end

    def sanitize_string_for_elasticsearch_string_query(str)
      # See http://stackoverflow.com/questions/16205341/symbols-in-query-string-for-elasticsearch

      # Escape special characters (except ':~*' which is used for wildcard searches)
      escaped_characters = Regexp.escape('\\+-&|!(){}[]^?\/')
      str = str.gsub(/([#{escaped_characters}])/, '\\\\\1')

      # AND, OR and NOT are used by lucene as logical operators. We need
      # to escape them
      ['AND', 'OR', 'NOT'].each do |word|
        escaped_word = word.split('').map {|char| "\\#{char}" }.join('')
        str = str.gsub(/\s*\b(#{word.upcase})\b\s*/, " #{escaped_word} ")
      end

      # Escape odd quotes
      quote_count = str.count '"'
      str = str.gsub(/(.*)"(.*)/, '\1\"\2') if quote_count % 2 == 1
      str
    end


    # ONLY these fields are returned from ES
    def compile_return_fields
      fields = return_fields.split(',').compact.uniq
      fields.map {|f| "pristine.#{f}"}
    end

  end
end
