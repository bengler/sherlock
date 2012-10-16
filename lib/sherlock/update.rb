require_relative '../../config/environment'
require 'pebblebed'

module Sherlock

  class Update

    attr_reader :payload, :events

    def initialize(message)
      @payload = JSON.parse message[:payload]
      @event = payload['event']
    end


    def build_index_records(payload)
      # Create a record for each entry in paths
      Sherlock::Parsers::Grove.build_records(payload['uid'], payload['attributes'])
    end


    # Returns an array of hashes, each hash representing a single executable task for elasticsearch
    # e.g.: [{'action' => 'index', 'record' => {'uid' => 'u:i.d'}}, {'action' => 'unindex', 'record' => {'uid' => 'u:i.d.e'}]
    def tasks
      # Temporary hack in order to not index email addresses contained in dittforslag posts
      return [] if Update.message_is_from_dittforslag(payload['uid'])
      # TODO we should configure somewhere which klasses should be indexed
      return [] unless payload['uid'] =~ /^post/

      result = []

      # Find all records matching uid
      uids = Sherlock::Elasticsearch.matching_uids(payload['uid'])

      records_for_indexing = build_index_records payload
      records_for_indexing.each do |record|
        case payload['event']
        when 'create', 'update', 'exists'
          result << {'action' => 'index', 'record' => record}
        when 'delete'
          result << {'action' => 'unindex', 'record' => {'uid' => record['uid']}}
        else
          LOGGER.warn "Sherlock update says: Unknown event type #{payload['event']}"
        end
        uids.delete record['uid']
      end

      # Add unindex tasks for paths which where not included in the message
      uids.each do |uid|
        result << {'action' => 'unindex', 'record' => {'uid' => uid}}
      end
      result
    end


    def self.message_is_from_dittforslag(uid)
      Pebbles::Uid.path(uid)[0, 19] == 'mittap.dittforslag.'
    end


  end

end
