require 'pebblebed'

class Sherlock

  class StreamGroup
    include Enumerable

    attr_reader :streams, :interval, :subscription
    def initialize(options = {})
      options = default_options.merge(options)
      @streams = []
      @interval = options[:interval] || 1
      @subscription = {:name => options[:name], :path => options[:path], :klass => options[:klass]}
    end

    def default_options
      {}
    end

    def setup
      raise NotImplementedError.new("Don't know anything about setting up the stream group.")
    end

    def each(&block)
      streams.each {|stream| block.call(stream) }
    end

    def <<(element)
      streams << element
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

    def consider(message)
      payload = JSON.parse(message[:payload])
      each { |stream| stream.consider payload }
    end

    private

    def process
      river = Pebblebed::River.new
      queue = river.queue subscription
      queue.subscribe(ack: true) do |message|
        consider message
      end
    end

  end
end
