#!/usr/bin/env ruby
require './config/environment.rb'

module Sherlock

  class UpdateListener

    def call(message)
      consider message.payload
      nil
    end

    def consider(payload)
      LOGGER.info("Consider #{payload.inspect}")
      matching_uids = begin
        Sherlock::Elasticsearch.matching_records(payload['attributes'])
      rescue Sherlock::Elasticsearch::OldRecordError
        # payload represents an older record, dont touch it
        return
      end

      tasks = Sherlock::Update.new(payload).tasks(matching_uids)
      tasks.each do |task|
        case task['action']
        when 'index'
          Sherlock::Elasticsearch.index task['record']
        when 'unindex'
          Sherlock::Elasticsearch.unindex task['record']['uid']
        end
      end
    end

  end

end
