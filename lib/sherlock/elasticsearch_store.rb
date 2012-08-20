require_relative './pebble_store'

class Sherlock
  class ElasticsearchStore < PebbleStore

    def service
      'elasticsearch'
    end

    def post(path, options)
      #client.post("/posts/#{options[:uid]}/paths/#{path}")
    end

    def delete(path, options)
      #client.delete("/posts/#{options[:uid]}/paths/#{path}")
    end

  end
end
