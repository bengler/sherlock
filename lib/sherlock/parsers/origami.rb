require 'pebblebed'

module Sherlock
  module Parsers
    class Origami

      attr_reader :uid, :record
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
        restricted = record['restricted'] ? record['restricted'] : false
        flatten.merge(expand).merge('realm' => realm, 'uid' => uid.to_s, 'pristine' => @record, 'restricted' => restricted)
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
        [Sherlock::Parsers::Origami.new(uid, attributes).to_hash]
      end

    end
  end
end