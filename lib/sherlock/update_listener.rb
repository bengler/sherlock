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
      tasks = Sherlock::Update.new(message).tasks
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
