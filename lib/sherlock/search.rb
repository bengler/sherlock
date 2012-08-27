require 'pebblebed'

module Sherlock
  
  class Search

    class << self
      def root_url
        "http://localhost:9200"
      end

      def index(record)
        Pebblebed::Http.put(url(record), record)
      end

      def unindex(record)
        Pebblebed::Http.delete(url(record), record) # TODO finn ut hva param 2 skal ha
      end

      def delete_index(realm)
        begin
          Pebblebed::Http.delete("#{root_url}/#{index_for(realm)}", {})
        rescue Pebblebed::HttpError => e
          raise e unless e.message =~ /IndexMissingException/
        end
      end

      def url(record)
        "#{root_url}/#{index_for(record['realm'])}/#{record_type(record)}/#{record['uid']}"
      end

      def index_for(realm)
        "#{ENV['RACK_ENV']}_#{realm}"
      end

      def record_type(record)
        Pebblebed::Uid.new(record['uid']).klass
      end

      # Perform a very simple search query across all fields.
      # Passes through options (such as :size, and :from) to elasticsearch.
      def query(realm, query_string, options = {})
        result = perform_query(realm, query_string, options)
        instantiate_from_search_result(result)
      end

      def perform_query(realm, query_string, options = {})
        url = "#{root_url}/#{index_for(realm)}/_search"
        options.merge!({:q => query_string, :default_operator => 'AND'})
        response = Pebblebed::Http.get(url, options)
        JSON.parse(response.body)
      end


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


end
