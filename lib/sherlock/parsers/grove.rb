require 'pebblebed'
require 'active_support/core_ext/hash/keys'

module Sherlock
  module Parsers
    class Grove

      attr_reader :uid, :record
      def initialize(uid, record)
        @record = record
        @uid = Pebbles::Uid.new(uid)
      end

      def realm
        uid.realm
      end

      def klass
        uid.genus
      end

      def path
        uid.path
      end

      def oid
        @oid ||= uid.oid
      end

      def to_hash
        restricted = record['restricted'] ? record['restricted'] : false
        flatten.merge(expand).merge('realm' => realm, 'uid' => uid.to_s, 'pristine' => @record, 'restricted' => restricted)
      end

      def flatten
        @flattened ||= flatten_hash(@record)
      end

      def expand
        unless @expanded
          klasses = Pebbles::Uid::Labels.new(klass, :name => 'klass', :suffix => '')
          labels = Pebbles::Uid::Labels.new(path, :name => 'label', :suffix => '')
          @expanded = klasses.to_hash.merge(labels.to_hash).merge('oid_' => oid).stringify_keys
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
        pebbles_uid = Pebbles::Uid.new(uid)
        attributes['paths'].each do |new_path|
          new_uid = "#{pebbles_uid.genus}:#{new_path}$#{pebbles_uid.oid}"
          records << Sherlock::Parsers::Grove.new(new_uid, attributes).to_hash
        end
        records
      end

    end
  end
end
