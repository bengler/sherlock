require 'pebblebed'

module Sherlock
  class GroveRecord

    attr_reader :uid
    def initialize(uid, record)
      @record = record
      @uid = Pebblebed::Uid.new(uid)
    end

    def realm
      uid.realm
    end

    def klass
      uid.klass
    end

    def path
      uid.path
    end

    def oid
      @oid ||= uid.oid
    end

    def to_hash
      flatten.merge(expand).merge('realm' => realm, 'uid' => uid.to_s).reject{|key, value| key == 'paths'}
    end

    def flatten
      @flattened ||= flatten_hash(@record)
    end

    def expand
      unless @expanded
        klasses = Pebblebed::Labels.new(klass, :prefix => 'klass', :suffix => '')
        labels = Pebblebed::Labels.new(path, :suffix => '')
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

    def self.build_records(uid, attributes)
      records = []
      klass, path, oid = Pebblebed::Uid.parse(uid)
      attributes['paths'].each do |new_path|
        new_uid = "#{klass}:#{new_path}$#{oid}"
        records << Sherlock::GroveRecord.new(new_uid, attributes).to_hash
      end
      records
    end

  end
end
