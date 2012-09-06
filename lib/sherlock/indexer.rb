require 'pebblebed'

module Sherlock

  class Indexer

    attr_reader :interval, :subscription

    def initialize(options = {})
      options.merge! default_options
      @interval = options[:interval]
      @subscription = {:name => options[:name], :path => options[:path], :klass => options[:klass]}
    end

    def default_options
      {:name => 'sherlock.index',
       :path => '**',
       :klass => '**',
       :event => '**',
       :interval => 1}
    end

    def build_index_records(payload)
      # create a record for each entry in paths
      Sherlock::GroveRecord.build_records(payload['uid'], payload['attributes'])
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

    def process
      river = Pebblebed::River.new
      queue = river.queue subscription
      queue.subscribe(ack: true) do |message|
        consider message
      end
    end

    def consider(message)
      payload = JSON.parse message[:payload]
      records = build_index_records payload
      records.each do |record|
        event = payload['event']
        if event == 'create' || event == 'update' || event == 'exists'
          Search.index record
        elsif event == 'delete'
          Search.unindex record
        else
          LOGGER.warn "Sherlock indexer says: Unknown event type #{event}"
        end
      end
    end

  end

end
