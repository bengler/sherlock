require 'pebblebed'

module Sherlock

  class Search

    class << self
      def root_url
        "http://localhost:9200"
      end

      def index(record)
        begin
          Pebblebed::Http.put(url(record['uid']), record)
        rescue Pebblebed::HttpError => e
          LOGGER.warn "Error while indexing #{record['uid']}"
          LOGGER.error e
        end
      end

      def unindex(uid)
        begin
          Pebblebed::Http.delete(url(uid), nil)
        rescue Pebblebed::HttpError => e
          LOGGER.warn "Error while unindexing #{uid}"
          LOGGER.error e
        end
      end

      def create_index(realm)
        begin
          index = index_for(realm)
          Pebblebed::Http.put("#{root_url}/#{index}", {})
        rescue Pebblebed::HttpError => e
          unless e.message =~ /IndexAlreadyExistsException/
            LOGGER.warn "Error while creating index #{index}"
            LOGGER.error e
          end
        end
      end

      def delete_index(realm)
        begin
          Pebblebed::Http.delete("#{root_url}/#{index_for(realm)}", {})
        rescue Pebblebed::HttpError => e
          unless e.message =~ /IndexMissingException/
            LOGGER.warn "Error while deleting index #{index}"
            LOGGER.error e
          end
        end
      end

      def url(uid_string)
        uid = Pebblebed::Uid.new(uid_string)
        "#{root_url}/#{index_for(uid.realm)}/#{uid.klass}/#{uid_string}"
      end

      def index_for(realm)
        "#{ENV['RACK_ENV']}_#{realm}"
      end

      def query(realm, query_obj)
        index = index_for(realm)
        url = "#{root_url}/#{index}/_search"
        result = nil
        options = Hash[:source => query_obj.to_json]
        begin
          response = Pebblebed::Http.get(url, options)
          result = JSON.parse(response.body)
        rescue Pebblebed::HttpError => e
          if e.message =~ /IndexMissingException/
            LOGGER.warn "Attempt to query non-existing index: #{index} (mostly harmless)"
          else
            LOGGER.warn "Unexpected error during query at index: #{index} with options: #{options}"
            LOGGER.error e
          end
        end
        result
      end

      def matching_uids(uid_string)
        uid = Pebblebed::Uid.new(uid_string)
        wildcard_uid = "#{uid.klass}:#{uid.realm}.*$#{uid.oid}"
        query = Sherlock::Query.new(:uid => wildcard_uid)
        matching = Sherlock::Search.query(uid.realm, query)
        return [] unless matching
        matching['hits']['hits'].map{|result| result['_id']}.compact
      end

    end

  end


end
