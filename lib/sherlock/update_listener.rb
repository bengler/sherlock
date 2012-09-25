require_relative '../../config/environment'
require 'pebblebed'

module Sherlock

  class UpdateListener

    attr_reader :interval, :subscription

    def initialize(options = {})
      options = default_options.merge(options)
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
      event = payload['event']

      # temporary hack in order to not index email addresses contained in dittforslag posts
      return if message_is_from_dittforslag(payload['uid'])

      # TODO we should configure somewhere which klasses should be indexed
      return unless payload['uid'] =~ /^post/

      # find all records matching uid
      uids = Search.matching_uids(payload['uid'])

      # update index for new records
      records_for_indexing = build_index_records payload
      records_for_indexing.each do |record|
        if event == 'create' || event == 'update' || event == 'exists'
          Search.index record
        elsif event == 'delete'
          Search.unindex record['uid']
        else
          LOGGER.warn "Sherlock indexer says: Unknown event type #{event}"
        end
        uids.delete record['uid']
      end

      # unindex matching paths which were not mentioned
      uids.each do |uid|
        Search.unindex uid
      end
    end


    def message_is_from_dittforslag(uid)
      Pebblebed::Uid.new(uid).path[0, 19] == 'mittap.dittforslag.'
    end


  end

end
