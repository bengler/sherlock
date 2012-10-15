require_relative '../../config/environment'
require 'pebblebed'

module Sherlock

  class Update

    attr_reader :payload

    def initialize(message)
      @payload = JSON.parse message[:payload]
    end


    def build_index_records(payload)
      uid = payload['uid']
      attributes = payload['attributes']

      if Sherlock::UidOriginIdentifier.grove?(uid)
        return Sherlock::Parsers::Grove.build_records(uid, attributes)
      elsif Sherlock::UidOriginIdentifier.origami?(uid)
        return Sherlock::Parsers::Origami.build_records(uid, attributes)
      else
        LOGGER.info "Sherlock doesn't know which parser to use on UID #{uid} ?"
        return []
      end
    end


    # Returns an array of hashes, each hash representing a single executable task for elasticsearch
    # e.g.: [{'action' => 'index', 'record' => {'uid' => 'u:i.d'}}, {'action' => 'unindex', 'record' => {'uid' => 'u:i.d.e'}]
    def tasks
      result = []

      return result unless Sherlock::Update.acceptable_origin?(payload['uid'])

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


    # Disregard dittforslag content
    # Only index grove and origami stuff
    def self.acceptable_origin?(uid)
      return false if Sherlock::UidOriginIdentifier.dittforslag?(uid)
      Sherlock::UidOriginIdentifier.grove?(uid) || Sherlock::UidOriginIdentifier.origami?(uid)
    end

  end

end
