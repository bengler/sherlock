require 'pebblebed'

module Sherlock
  class UIDQuery

    attr_reader :klass, :path, :oid
    def initialize(uid)
      @klass, @path, @oid= Pebblebed::Uid.raw_parse(uid)
    end

    def filters
      @filters ||= { "filter" => terms.merge(missing) }
    end

    def klasses
      @klasses ||= Pebblebed::Labels.new(klass, :prefix => 'klass', :suffix => '')
    end

    def labels
      @labels ||= Pebblebed::Labels.new(path, :suffix => '')
    end

    def terms
      unless @terms
        _oid = oid ? {'oid_' => oid} : {}
        @terms = {"terms" => klasses.expanded.merge(labels.expanded).merge(_oid)}
      end
      @terms
    end

    def missing
      unless @missing
        if Pebblebed::Uid.wildcard_path?(path)
          @missing = {}
        else
          @missing = {'missing' => {'field' => labels.next}}
        end
      end
      @missing
    end
  end
end
