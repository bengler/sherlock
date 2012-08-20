module Search

  NotIndexed = Class.new

  class << self
    def root_url
      "http://localhost:9200"
    end

    def index_this(object)
      update object
    end

    def update(object)
      url = "#{root_url}/#{index_for(object['realm'])}/post/#{object['uid']}"
      Pebblebed::Http.put(url, object.to_json)
    end

    def index_for(realm)
      "#{ENV['RACK_ENV']}_#{realm}"
    end

    # Perform a very simple search query across all fields.
    # Passes through options (such as :size, and :from) to elasticsearch.
    def query(realm, query_string, options = {})
      result = perform_query(realm, query_string, options)
      instantiate_from_search_result(result)
    end

    def perform_query(realm, query_string, options = {})
      url = "#{root_url}/#{index_for(realm)}/_search"
      response = Pebblebed::Http.get(url, {:q => query_string, :default_operator => 'AND'}.merge(options))
      JSON.parse(response.body)
    end

    private

    # Creates readonly model objects from a search result
    def instantiate_from_search_result(result)
      result['hits']['hits'].map do |hit|
        klass = Object.const_get(hit['_type'].classify)
        object = klass.instantiate(hit["_source"])
        object.readonly!
        object
      end
    end

  end
end
