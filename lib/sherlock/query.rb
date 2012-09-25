module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset, :sort_attribute, :order
    def initialize(options = {})
      @search_term = options[:q]
      @limit = options[:limit]
      @offset = options[:offset]
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
      klass, path, oid = Pebblebed::Uid.raw_parse(uid)
      klasses = Pebblebed::Labels.new(klass, :prefix => 'klass', :suffix => '')
      labels = Pebblebed::Labels.new(path, :suffix => '')
      oids = oid ? {'oid_' => oid} : {}
      must = klasses.expanded.merge(labels.expanded).merge(oids).map do |key, value|
        {:term => {key => value}}
      end
      must << {:term => {'restricted' => false}}
      unless Pebblebed::Uid.wildcard_path?(path)
        must << {:missing => {:field => labels.next}}
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
