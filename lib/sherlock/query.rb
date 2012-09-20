module Sherlock
  class Query

    attr_reader :search_term, :uid, :limit, :offset
    def initialize(search_term, options = {})
      @search_term = search_term
      @limit = options[:limit]
      @offset = options[:offset]
      @uid = options[:uid]
      @uid = nil if @uid == '*:*'
    end

    def pagination
      bounds = {}
      bounds.merge!(:size => limit) if limit
      bounds.merge!(:from => offset) if offset
      bounds
    end

    def to_hash
      if uid
        {:query => {:filtered => term.merge(filters)}}.merge(pagination)
      else
        term.merge(pagination)
      end
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

  end
end
