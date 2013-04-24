
# Builds a chunk of JSON based on the query parameters, which can be passed to elasticsearch.

module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order, :range, :fields, :accessible_paths, :uid_query, :tags_query
    def initialize(options, accessible_paths = [])
      options.symbolize_keys!
      @search_term = options[:q]
      @limit = options.fetch(:limit) { 10 }
      @offset = options.fetch(:offset) { 0 }
      @uid = options[:uid] || '*:*'
      @sort_attribute = options[:sort_by]
      @order = Query.normalize_sort_order(options[:order])
      @range = options[:range]
      @fields = options.fetch(:fields) {[]}
      @accessible_paths = accessible_paths
      @uid_query = Pebbles::Uid.query(uid, :species => 'klass', :path => 'label', :suffix => '')
      @tags_query = options[:tags]
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
      if tags_queries
        tags_queries.each do |rk,rv|
          unless rv.empty?
            result[:filter] ||= {}
            result[:filter][rk] ||= []
            result[:filter][rk] << rv
            result[:filter][rk] << security_filter if security_filter
            result[:filter][rk] << missing_filter if missing_filter
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
      result << security_filter

      missing = missing_filter
      #result << {:constant_score => {:filter => missing}} if missing
      result << missing if missing
      return {:and => result} if result.count > 1
      return result.first if result.count == 1
      return nil
    end

    def bool_query
      queries = []
      queries << query_string if search_term
      queries = queries + uid_field_queries
      queries = queries + field_queries
      queries = queries << range_query if range
      {:must => queries}
    end

    def query_string
      { :query_string => {
          :query => search_term.downcase,
          :default_operator => 'AND'
        }
      }
    end

    def uid_field_queries
      result = uid_query.to_hash.map do |key, value|
        {:term => {key.to_s => value}}
      end
      result
    end

    def tags_queries
      if @tags_query
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
        return results
      end
      nil
    end

    # query on specific field value
    def field_queries
      result = []
      fields.each do |key, value|
        unless value == 'null'
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


    def range_query
      params = {}
      params['lte'] = range['to'] if range['to']
      params['gte'] = range['from'] if range['from']
      {:range => {range['attribute'] => params}}
    end

    def security_filter
      return {:term => {'restricted' => false}} if accessible_paths.empty?
      access_requirements = []
      accessible_paths.each do |path|
        requirement_set = []
        Pebbles::Uid::Labels.new(path, :name => 'label', :suffix => '').to_hash.each do |key, value|
          requirement_set << {:term => {key.to_s => value}}
        end
        access_requirements << {:and => requirement_set}
      end
      access_requirements << {:term => {'restricted' => false}}
      {:or => access_requirements}
    end

    def sort
      return {} unless sort_attribute
      {:sort => [{ sort_attribute => {'order' => order} }, '_score']}
    end

    def self.normalize_sort_order(order)
      if order.try(:downcase) == 'asc'
        return 'asc'
      end
      'desc'
    end

    def to_json
      to_hash.to_json
    end

  end
end
