
# Builds a chunk of JSON based on the query parameters, which can be passed to elasticsearch.

module Sherlock
  class Query

    REQUIRED_RETURN_FIELDS = ['uid']

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order, :min, :max, :deprecated_range, :fields, :accessible_paths, :uid_query, :tags_query, :deleted, :unpublished, :return_fields
    def initialize(options, accessible_paths = [])
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
      @unpublished = options[:unpublished]
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

      tags_query_result = tags_queries
      if tags_query_result
        tags_query_result.each do |rk,rv|
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
      must_nots = negative_field_queries
      result = {:must => queries}
      result[:must_not] = must_nots unless must_nots.empty?
      result
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
          if a.strip[0] == "!"
            results[:and] << {
              "not" => { "term" => { "tags_vector" => a.gsub("!", "").strip} }
            }
          else
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
          end
        end
      end
      results
    end

    # query on specific field value
    def field_queries
      result = []
      fields.each do |key, value|
        next unless value
        is_negative_query = value.start_with? '!'
        is_null_query = (value == 'null' || value == '!null')

        if !is_negative_query && !is_null_query
          if value.match(/\|/) # A value containing a pipe will be parsed as an OR statement
            result << {:terms => {key => value.downcase.split('|')}}
          else
            result << {:term => {key => value.downcase}}
          end
        end
      end
      result
    end

    # query on specific NOT field value
    def negative_field_queries
      result = []
      fields.each do |key, value|
        next unless value
        is_negative_query = value.start_with? '!'
        is_null_query = (value == 'null' || value == '!null')

        if is_negative_query && !is_null_query
          not_value = "#{value[1..-1]}" # remove exclamation mark from position 0
          if not_value.match(/\|/) # A value containing a pipe will be parsed as an OR statement
            result << {:terms => {key => not_value.downcase.split('|')}}
          else
            result << {:term => {key => not_value.downcase}}
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
      default_filters = [
        {:term => {'restricted' => false}},
        published_true_or_blank,
        deleted_false_or_blank
      ]

      # Non-privileged filter
      non_privileged_access_filters = {:and => (default_filters + deleted_and_unpublished_filters).uniq}

      # Early return in case user has no privileged paths
      return non_privileged_access_filters if accessible_paths.empty?

      # Build filter for the privileged paths
      # Extract labels from each privileged path and apply deleted/unpublished filters to them
      privileged_access_filters = []
      accessible_paths.each do |path|
        requirement_set = []
        Pebbles::Uid::Labels.new(path, :name => 'label', :suffix => '').to_hash.each do |key, value|
          requirement_set << {:term => {key.to_s => value}}
        end
        privileged_access_filters << {:and => (requirement_set + deleted_and_unpublished_filters)}
      end

      {:or => privileged_access_filters + [non_privileged_access_filters]}
    end



    def deleted_and_unpublished_filters
      filters = []
      # Handle unpublished flag
      if unpublished == 'only'
        # Explicitly include only unpublished records
        filters << {:term => {'published' => false}}
      elsif unpublished == 'include'
        # No extra filter -> include both published and unpublished
      else
        # Include published records, and those where we have no published field
        filters << published_true_or_blank
      end

      # Handle deleted flag
      if deleted == 'only'
        # Explicitly include only deleted records
        filters << {:term => {'deleted' => true}}
      elsif deleted == 'include'
        # No extra filter -> include both deleted and non-deleted
      else
        # Exclude deleted records, but include them if we dont know
        filters << deleted_false_or_blank
      end
      filters
    end


    def published_true_or_blank
      {
        :or => [
          {:term => {'published' => true}},
          {:missing => {:field => 'published', :existence => true, :null_value => true}}
        ]
      }
    end


    def deleted_false_or_blank
      {
        :or => [
          {:term => {'deleted' => false}},
          {:missing => {:field => 'deleted', :existence => true, :null_value => true}}
        ]
      }
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
      (REQUIRED_RETURN_FIELDS + return_fields).uniq.map {|f| "pristine.#{f}"}
    end

  end
end
