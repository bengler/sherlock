require 'pebblebed'

class Sherlock
  class PebbleStore

    attr_reader :include_on, :exclude_on
    def initialize(options = {})
      @include_on = Array(options[:include_on] || 'create')
      @exclude_on = Array(options[:exclude_on] || 'delete')
    end

    def service
      raise NotImplementedError.new("You have to implement `service`.")
    end

    def post(path, options)
      raise NotImplementedError.new("You have to implement `service`.")
    end

    def delete(path, options)
      raise NotImplementedError.new("You have to implement `service`.")
    end

    def client
      unless @client
        config = Sherlock.config[service]
        @client = Pebblebed::Connector.new(config['session'], :host => config['host'])[service]
      end
      @client
    end

    def include(path, options = {})
      raise ArgumentError.new('Please specify uid with :uid => the_uid') unless options[:uid]
      raise ArgumentError.new('Please specify event with :event => the_event') unless options[:event]

      return unless include_event?(options[:event])

      post(path, options)
    end

    def exclude(path, options = {})
      raise ArgumentError.new('Please specify uid with :uid => the_uid') unless options[:uid]
      raise ArgumentError.new('Please specify event with :event => the_event') unless options[:event]

      return unless exclude_event?(options[:event])

      delete(path, options)
    end

    def include_event?(event)
      include_on.include?(event)
    end

    def exclude_event?(event)
      exclude_on.include?(event)
    end

  end
end
