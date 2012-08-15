class Sherlock
  class Stream

    attr_reader :path, :stores, :matchers
    def initialize(options = {})
      options = default_options.merge(options)
      @path = options[:path]
      @stores = options[:stores] || []
      @matchers = options[:matchers]
    end

    def default_options
      {}
    end

    def consider(payload)
      if matchers.all? {|m| m.wants?(payload) }
        uid = payload['uid']
        event = payload['event']
        stores.each do |store|
          store.include(path, :uid => uid, :event => event)
          store.exclude(path, :uid => uid, :event => event)
        end
      end
    end

  end
end
