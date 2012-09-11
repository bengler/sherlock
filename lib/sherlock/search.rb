require 'pebblebed'

module Sherlock

  class Search

    class << self
      def root_url
        "http://localhost:9200"
      end

      def index(record)
        Pebblebed::Http.put(url(record['uid']), record)
      end

      def unindex(uid)
        Pebblebed::Http.delete(url(uid), nil)
      end

      def delete_index(realm)
        begin
          Pebblebed::Http.delete("#{root_url}/#{index_for(realm)}", {})
        rescue Pebblebed::HttpError => e
          raise e unless e.message =~ /IndexMissingException/
        end
      end

      def url(uid_string)
        uid = Pebblebed::Uid.new(uid_string)
        "#{root_url}/#{index_for(uid.realm)}/#{uid.klass}/#{uid_string}"
      end

      def index_for(realm)
        "#{ENV['RACK_ENV']}_#{realm}"
      end

      def query(realm, options = {})
        url = "#{root_url}/#{index_for(realm)}/_search"
        result = nil
        begin
          response = Pebblebed::Http.get(url, options)
          result = JSON.parse(response.body)
        rescue Pebblebed::HttpError => e
          raise e unless e.message =~ /IndexMissingException/
          #TODO: We should return something prettier than nil if we get indexmissing/404, maybe something like an ordinary result?
        end
        result
      end


      def matching_uids(uid_string)
        uid = Pebblebed::Uid.new(uid_string)
        wildcard_uid = "#{uid.klass}:#{uid.realm}.*$#{uid.oid}"
        query = Sherlock::Query.new(nil, :uid => wildcard_uid)
        matching = Sherlock::Search.query(uid.realm, :source => query.to_json)
        return [] unless matching
        matching['hits']['hits'].map{|result| result['_id']}.compact
      end

    end

  end


end
