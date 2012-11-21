module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order, :show_restricted, :range, :fields
    def initialize(options = {})
      options.symbolize_keys!
      @search_term = options[:q]
      @limit = options.fetch(:limit) { 10 }
      @offset = options.fetch(:offset) { 0 }
      @uid = options[:uid] || '*:*'
      @sort_attribute = options[:sort_by]
      @order = Query.normalize_sort_order(options[:order])
      @show_restricted = options.fetch(:show_restricted) {false}
      @range = options[:range]
      @fields = options.fetch(:fields) {[]}
    end

    def pagination
      bounds = {}
      bounds.merge!(:size => limit) if limit
      bounds.merge!(:from => offset) if offset
      bounds
    end

    def to_hash
      {:query => {:filtered => term.merge(filters)}}.merge(pagination).merge(sort)
    end

    def to_json
      to_hash.to_json
    end

    def term
      if search_term
        { :query => { :query_string => { :query => search_term.downcase, :default_operator => 'AND' } } }
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
      query = Pebbles::Uid.query(uid, :species => 'klass', :path => 'label', :suffix => '')
      must = query.to_hash.map do |key, value|
        {:term => {key.to_s => value}}
      end
      must << {:term => {'restricted' => false}} unless show_restricted
      unless query.path =~ /\*$/
        must << {:missing => {:field => query.next_path_label}}
      end

      fields.each do |key, value|
        if value == 'null'
          must << {:missing => {:field => key}}
        elsif value.match(/\|/) # TODO: evaluate use of the pipe operator, this will not work with fields which value should contain a pipe!
          must << {:terms => {key => value.downcase.split('|')}}
        else
          must << {:term => {key => value.downcase}}
        end
      end

      must << {:range => range_filter} if range
      return {} if must.empty?
      {:filter => {:bool => {:must => must}}}
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
