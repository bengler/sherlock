require_relative '../../config/environment'
require 'pebblebed'

module Sherlock

  class Update

    attr_reader :payload

    def initialize(message)
      @payload = JSON.parse message[:payload]
    end


    def build_index_records(payload)
      LOGGER.info("Build index: #{payload}")

      Sherlock::Parsers::Generic.build_records(payload['uid'], payload['attributes'])
    end


    # Returns an array of hashes, each hash representing a single executable task for elasticsearch
    # e.g.: [{'action' => 'index', 'record' => {'uid' => 'u:i.d'}}, {'action' => 'unindex', 'record' => {'uid' => 'u:i.d.e'}]
    def tasks(matching_uids = [])
      result = []

      records_for_indexing = build_index_records payload
      records_for_indexing.each do |record|
        case payload['event']
        when 'create', 'update', 'exists'
          # unindex explicitly unpublished records
          if unpublished?
            result << {'action' => 'unindex', 'record' => {'uid' => record['uid']}}
          else
            result << {'action' => 'index', 'record' => record}
          end
        when 'delete'
          if soft_deleted?
            result << {'action' => 'index', 'record' => record}
          else
            result << {'action' => 'unindex', 'record' => {'uid' => record['uid']}}
          end
        else
          LOGGER.warn "Sherlock update says: Unknown event type #{payload['event']} for payload #{payload.inspect}"
        end
        matching_uids.delete record['uid']
      end

      # Add an unindex task for record which where not mentioned in message paths
      matching_uids.each do |uid|
        result << {'action' => 'unindex', 'record' => {'uid' => uid}}
      end
      result
    end

    def unpublished?
      payload['attributes']['published'] == false
    end

    def soft_deleted?
      payload['soft_deleted'] == true
    end

  end

end
