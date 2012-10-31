require_relative '../../config/environment'
require 'pebblebed'

module Sherlock

  class Update

    attr_reader :payload

    def initialize(message)
      @payload = JSON.parse message[:payload]
    end


    def build_index_records(payload)
      Sherlock::Parsers::Generic.build_records(payload['uid'], payload['attributes'])
    end


    # Returns an array of hashes, each hash representing a single executable task for elasticsearch
    # e.g.: [{'action' => 'index', 'record' => {'uid' => 'u:i.d'}}, {'action' => 'unindex', 'record' => {'uid' => 'u:i.d.e'}]
    def tasks(matching_uids = [])
      result = []
      return result unless Sherlock::Update.acceptable_origin?(payload['uid'])

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
        matching_uids.delete record['uid']
      end

      # Add an unindex task for record which where not mentioned in message paths
      matching_uids.each do |uid|
        result << {'action' => 'unindex', 'record' => {'uid' => uid}}
      end
      result
    end

    # Disregard dittforslag content
    # Only index grove and origami stuff
    # TODO: blacklist checkpoint and whitelist all other stuff when we know what checkpoints namespace is
    def self.acceptable_origin?(uid)
      return false unless uid
      return false if Sherlock::UidOriginIdentifier.dittforslag?(uid)
      Sherlock::UidOriginIdentifier.grove?(uid) || Sherlock::UidOriginIdentifier.origami?(uid)
    end

  end

end
