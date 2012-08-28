require 'pebblebed'

module Sherlock
  class GroveRecord

    attr_reader :klass, :path, :oid

    def initialize(payload)
      @payload = payload
      @klass, @path, @oid = Pebblebed::Uid.parse(payload['uid'])
      @oid = @oid.to_i
    end

    def to_hash
      flatten.merge(expand)
    end

    def flatten
      @flattened ||= flatten_hash(@payload)
    end

    def expand
      unless @expanded
        klasses = Pebblebed::Labels.new(klass, :prefix => 'klass', :suffix => '')
        labels = Pebblebed::Labels.new(path, :suffix => '', :stop => '<END>')
        @expanded = klasses.expanded.merge(labels.expanded).merge('oid_' => oid)
      end
      @expanded
    end


    def flatten_hash(hash_to_flatten, parent_key = "")
      result = {}
      hash_to_flatten.each_pair do |key, val|
        flat_key = parent_key.empty? ? key : "#{parent_key}.#{key}"
        if val.is_a?(Hash)
          result.merge!(flatten_hash(val, flat_key))
        else
          result[flat_key] = val
        end
      end
      result
    end

  end
end
