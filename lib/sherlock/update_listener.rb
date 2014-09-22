#!/usr/bin/env ruby
require './config/environment.rb'

module Sherlock

  class UpdateListener

    def call(message)
      consider message.payload
      nil
    end

    def consider(payload)
      LOGGER.info("Consider #{payload['uid']}")
      matching_uids = begin
        Sherlock::Elasticsearch.matching_records({'uid' => payload['uid']}.merge(payload['attributes']))
      rescue Sherlock::Elasticsearch::OldRecordError
        # payload represents an older record, dont touch it
        return
      end

      begin
      tasks = Sherlock::Update.new(payload).tasks(matching_uids)
      tasks.each do |task|
        case task['action']
        when 'index'
          Sherlock::Elasticsearch.index task['record']
        when 'unindex'
          Sherlock::Elasticsearch.unindex task['record']['uid']
        end
      end
      rescue ArgumentError => e
        raise e unless /\.\.side3/.match e.message
      end
    end

  end

end
