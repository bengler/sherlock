require 'pebblebed'

module Sherlock

  class Indexer

    attr_reader :interval, :subscription

    def initialize(options = nil)
      #TODO: fix these defaults, maybe read from config/river_subscription.yml or somesuch
      defaults = {:name => 'highway_to_hell',
                  :path => 'hell.*|realm.stuff',
                  :klass => 'post.card',
                  :interval => 1}

      options ||= defaults
      @interval = options[:interval]
      @subscription = {:name => options[:name], :path => options[:path], :klass => options[:klass]}
    end

    def build_index_record(payload)
      result = payload['attributes']
      result['realm'] = Pebblebed::Uid.new(payload['uid']).realm
      result['uid'] = payload['uid']
      result
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
      payload = JSON.parse message[:payload]
      record = build_index_record payload

      event = payload['event']
      if event == 'create' || event == 'update'
        Search.index record
      elsif event == 'delete'
        Search.unindex record
      else
        LOGGER.warn "Sherlock indexer says: Unknown event type #{event}"
      end
    end

  end

end
