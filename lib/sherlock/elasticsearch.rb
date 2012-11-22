require 'pebblebed'

module Sherlock

  class Elasticsearch

    class << self
      def root_url
        "http://localhost:9200"
      end

      def index(record)
        begin
          Pebblebed::Http.put(url(record['uid']), record)
        rescue Pebblebed::HttpError => e
          if e.message =~ /IndexMissingException/
            create_index(Pebbles::Uid.new(record['uid']).realm, index_config)
            # now try again
            index(record)
          else
            LOGGER.warn "Error while indexing #{record['uid']}"
            LOGGER.error e
          end
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

      def delete_index(realm, should_prefix_realm = true)
        index = should_prefix_realm ? index_name(realm) : realm
        begin
          Pebblebed::Http.delete("#{root_url}/#{index}", {})
        rescue Pebblebed::HttpError => e
          unless e.message =~ /IndexMissingException/
            LOGGER.warn "Error while deleting index #{index}"
            LOGGER.error e
          end
        end
      end

      def create_index(realm, config)
        index = index_name(realm)
        begin
          Pebblebed::Http.put("#{root_url}/#{index}", config)
          LOGGER.info "Created index #{index}"
        rescue Pebblebed::HttpError => e
          LOGGER.warn "Unexpected error while creating index #{index}"
          LOGGER.error e
        end
      end

      def server_status(realm = nil)
        url = "#{root_url}"
        url << "/#{index_name(realm)}" if realm
        url << "/_status"
        begin
          response = Pebblebed::Http.get(url, {})
          result = JSON.parse(response.body)
        rescue Pebblebed::HttpError => e
          LOGGER.warn "Unexpected error on GET #{url}"
          LOGGER.error e
        end
        result
      end

      def url(uid_string)
        uid = Pebbles::Uid.new(uid_string)
        "#{root_url}/#{index_name(uid.realm)}/#{uid.species}/#{uid_string}"
      end

      def index_name(realm)
        "sherlock_#{ENV['RACK_ENV']}_#{realm}"
      end

      def query(realm, query_obj)
        index = index_name(realm)
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

      # Returns an array of all records in elasticsearch with the same species:realm.*$oid
      def matching_records(uid_string)
        uid = Pebbles::Uid.new(uid_string)
        query = Sherlock::Query.new({:uid => uid.cache_key}, [uid.realm])
        matching = Sherlock::Elasticsearch.query(uid.realm, query)
        return [] unless matching
        matching['hits']['hits'].map{|result| result['_id']}.compact
      end

      def index_config
        { :settings => {
            :analysis => {
              :analyzer => {
                :default => {
                  :type => "custom",
                  :filter => ["lowercase"],
                  :tokenizer => "whitespace"
                }
              }
            }
          }
        }
      end

    end

  end


end
