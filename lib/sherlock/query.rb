module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order, :range, :fields, :accessible_paths
    def initialize(options = {})
      options.symbolize_keys!
      @search_term = options[:q]
      @limit = options.fetch(:limit) { 10 }
      @offset = options.fetch(:offset) { 0 }
      @uid = options[:uid] || '*:*'
      @sort_attribute = options[:sort_by]
      @order = Query.normalize_sort_order(options[:order])
      @range = options[:range]
      @fields = options.fetch(:fields) {[]}
      @accessible_paths = options.fetch(:accessible_paths) {[]}
    end

    def pagination
      bounds = {}
      bounds.merge!(:size => limit) if limit
      bounds.merge!(:from => offset) if offset
      bounds
    end

    def to_hash
      {:query => {:filtered => query_term.merge(filters)}}.merge(pagination).merge(sort)
    end

    def to_json
      to_hash.to_json
    end

    def query_term
      if search_term
        { :query => {
          :query_string => {
            :query => search_term.downcase,
            :default_operator => 'AND' }
          }
        }
      else
        { :query => { :match_all => {} } }
      end
    end

    def sort
      if sort_attribute
        {:sort => [{"document.#{sort_attribute}" => {'order' => order}},  '_score']}
      else
        {}
      end
    end

    def filters

      # uid query
      query = Pebbles::Uid.query(uid, :species => 'klass', :path => 'label', :suffix => '')
      and_queries = query.to_hash.map do |key, value|
        {:term => {key.to_s => value}}
      end
      unless query.path =~ /\*$/
        and_queries << {:missing => {:field => query.next_path_label}}
      end

      # query on specific field value
      fields.each do |key, value|
        if value == 'null'
          and_queries << {:missing => {:field => key}}
        elsif value.match(/\|/) # A value containing a pipe will be parsed as an OR statement
          and_queries << {:terms => {key => value.downcase.split('|')}}
        else
          and_queries << {:term => {key => value.downcase}}
        end
      end

      # ranged query
      and_queries << {:range => range_filter} if range

      # restricting access
      or_queries = []
      if accessible_paths.empty?
        and_queries << {:term => {'restricted' => false}}
      else
        accessible_paths.each do |path|
          or_query = []
          Pebbles::Uid::Labels.new(path, :name => 'label', :suffix => '').to_hash.each do |key, value|
            or_query << {:term => {key.to_s => value}}
          end
          or_queries << or_query
        end
      end

      # build filters hash from queries
      result = {}
      unless and_queries.empty?
        result[:filter] = {:and => and_queries}
      end
      unless or_queries.empty?
        result[:filter] ||= {}
        result[:filter][:or] = []
        or_queries.each do |query|
          result[:filter][:or] << {:and => query}
        end
      end
      result
    end


    def range_filter
        result = {}
        result['lte'] = range['to'] if range['to']
        result['gte'] = range['from'] if range['from']
        {range['attribute'] => result}
    end

    def self.normalize_sort_order(order)
      if order.try(:downcase) == 'asc'
        return 'asc'
      end
      'desc'
    end

  end
end
