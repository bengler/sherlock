module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order
    def initialize(options = {})
      options.symbolize_keys!
      @search_term = options[:q]
      @limit = options.fetch(:limit) { 10 }
      @offset = options.fetch(:offset) { 0 }
      @uid = options[:uid] || '*:*'
      @sort_attribute = options[:sort_by]
      @order = Query.normalize_sort_order(options[:order])
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
        { :query => { :query_string => { :query => search_term } } }
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
      _, path, _= Pebblebed::Uid.raw_parse(uid)

      query = Pebbles::Uid.query(uid, :genus => 'klass', :path => 'label', :suffix => '')
      must = query.to_hash.map do |key, value|
        {:term => {key.to_s => value}}
      end
      must << {:term => {'restricted' => false}}
      unless query.path =~ /\*$/
        must << {:missing => {:field => query.next_path_label}}
      end
      bool = {:bool => {:must => must}}
      {:filter => bool}
    end

    def self.normalize_sort_order(order)
      if order.try(:downcase) == 'asc'
        return 'asc'
      end
      'desc'
    end

  end
end
