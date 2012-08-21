require 'pebblebed'

module Search

  NotIndexed = Class.new

  class << self
    def root_url
      "http://localhost:9200"
    end

    def index_this(object)
      event = object['event']
      if event == 'create' || event == 'update'
        create_index object
      elsif event == 'delete'
        delete_index object
      end
    end

    def create_index(object)
      url = "#{root_url}/#{index_for(object['realm'])}/#{object_type(object)}/#{object['uid']}"
      Pebblebed::Http.put(url, object.to_json)
    end

    def delete_index(object)
      url = "#{root_url}/#{index_for(object['realm'])}/#{object_type(object)}/#{object['uid']}"
      Pebblebed::Http.delete(url, object.to_json)
    end

    def delete_entire_index(realm)
      begin
        Pebblebed::Http.delete("#{root_url}/#{index_for(realm)}", {})
      rescue Pebblebed::HttpError => e
        raise e unless e.message =~ /IndexMissingException/
      end
    end

    def index_for(realm)
      "#{ENV['RACK_ENV']}_#{realm}"
    end

    def object_type(object)
      Pebblebed::Uid.parse(object['uid']).first
    end

    # Perform a very simple search query across all fields.
    # Passes through options (such as :size, and :from) to elasticsearch.
    def query(realm, query_string, options = {})
      result = perform_query(realm, query_string, options)
      instantiate_from_search_result(result)
    end

    def perform_query(realm, query_string, options = {})
      url = "#{root_url}/#{index_for(realm)}/_search"
      response = Pebblebed::Http.get(url, options.merge({:q => query_string, :default_operator => 'AND'}))
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
