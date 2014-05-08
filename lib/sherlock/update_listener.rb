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
       :klass => 'post.*|unit|organization|group|capacity|associate|affiliation',
       :event => 'create|update|exists|delete',
       :interval => 1}
    end

    def start
      @thread = Thread.new do
        loop do
          begin
            process
          rescue Pebblebed::HttpError, Pebblebed::HttpNotFoundError, StandardError => e
            if false #LOGGER.respond_to?:exception
              LOGGER.exception(e)
            else
              LOGGER.error(e.inspect)
              LOGGER.error(e.backtrace.join("\n"))
            end
          end
        end
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
        begin
          consider message
        rescue Pebblebed::HttpError => e
          LOGGER.error(e.inspect)
        end
      end
    end

    def consider(message)
      payload_hash = JSON.parse(message[:payload])
      LOGGER.info("Considering: #{payload_hash}")

      matching_uids = Sherlock::Elasticsearch.matching_records(payload_hash['uid'])

      tasks = Sherlock::Update.new(message).tasks(matching_uids)
      tasks.each do |task|
        case task['action']
        when 'index'
          Sherlock::Elasticsearch.index task['record']
        when 'unindex'
          Sherlock::Elasticsearch.unindex task['record']['uid']
        else
          LOGGER.error "Sherlock questions the relevancy of task #{task['action']}."
        end
      end
    end

  end

end
