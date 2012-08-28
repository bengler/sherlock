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
      parse
      flatten
      expand
      {}
    end

    def parse
    end

    def flatten
    end

    def expand
      klasses = Pebblebed::Labels.new(klass, :prefix => 'klass', :suffix => '')
      labels = Pebblebed::Labels.new(path, :suffix => '', :stop => '<END>')
      klasses.expanded.merge(labels.expanded).merge('oid_' => oid)
    end

  end
end
