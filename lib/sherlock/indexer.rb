require 'pebblebed'

class Sherlock

  class Indexer

    attr_reader :interval, :subscription

    def initialize
      # nothing here yet
    end

    def setup(options = {})
      @interval = options[:interval] || 1
      @subscription = {:name => options[:name], :path => options[:path], :klass => options[:klass]}
    end

    def start
      @thread = Thread.new do
        process
      end
    end

    def stop
      @thread.kill if @thread
      @thread = nil
    end

    private

    def process
      river = Pebblebed::River.new
      queue = river.queue subscription
      queue.subscribe(ack: true) do |message|
        consider message
      end
    end

    def consider(message)
      object = JSON.parse(message[:payload])
      klass, path, oid = Pebblebed::Uid.parse(object['uid'])
      realm = path.split(".").first
      Search.index_this(object.merge('realm' => realm))
    end

  end
end
