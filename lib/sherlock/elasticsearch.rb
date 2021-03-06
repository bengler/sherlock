require 'pebblebed'

module Sherlock

  class Elasticsearch


    class QueryError < StandardError
      attr_reader :label, :message
      def initialize(options)
        @label = options[:label]
        @message = options[:message]
      end
    end

    class OldRecordError < StandardError
      attr_reader :label, :message
      def initialize(options)
        @label = options[:label]
        @message = options[:message]
      end
    end


    class << self

      def root_url
        "http://localhost:9200"
      end


      def url(uid_string)
        uid = Pebbles::Uid.new(uid_string)
        "#{root_url}/#{index_name(uid.realm)}/#{uid.species}/#{uid_string}"
      end


      def index_name(realm)
        "sherlock_#{ENV['RACK_ENV']}_#{realm}"
      end


      def predefined_mappings_for(realm)
        mappings_file_name = "./config/#{realm}/predefined_es_mappings.json"
        return {} unless File.exist? mappings_file_name
        predefined_mappings = JSON.parse(File.read(mappings_file_name))
        predefined_mappings['mappings'] || {}
      end

      def predefined_settings_for(realm)
        setting_file_name = "./config/#{realm}/predefined_es_settings.json"
        return nil unless File.exist? setting_file_name
        JSON.parse(File.read(setting_file_name))
      end

      def default_index_config
        {
          settings: {
            analysis: {
              analyzer: {
                default: {
                  type: 'custom',
                  filter: ['lowercase'],
                  tokenizer: 'whitespace'
                }
              }
            }
          }
        }
      end


      def index(record)
        begin
          if record['tags_vector']
            if record['tags_vector'].is_a? String
              record['tags_vector'] = record['tags_vector'].split("' '").map{|t| t.gsub("'", '')}
            end
            record['pristine']['tags_vector'] = record['tags_vector']
          end
          url = url(record['uid'])
          Pebblebed::Http.put(url, record)
        rescue Pebblebed::HttpError => e
          if e.message =~ /IndexMissingException/
            create_index(Pebbles::Uid.new(record['uid']).realm)
            # now try again
            index(record)
          else
            if LOGGER.respond_to?:exception
              LOGGER.exception(e)
            else
              LOGGER.error(e.inspect)
              LOGGER.error(e.backtrace.join("\n"))
            end
          end
        end
      end

      def unindex(uid)
        begin
          Pebblebed::Http.delete(url(uid), nil)
        rescue Pebblebed::HttpNotFoundError => e
          # no unindex-able resource found
          return false
        rescue Pebblebed::HttpError => e
          LOGGER.exception e
        end
        true
      end

      def delete_index(realm, should_prefix_realm = true)
        index = should_prefix_realm ? index_name(realm) : realm
        begin
          Pebblebed::Http.delete("#{root_url}/#{index}", {})
          return true
        rescue Pebblebed::HttpError => e
          unless e.message =~ /IndexMissingException/
            if LOGGER.respond_to?:exception
              LOGGER.exception(e)
            else
              LOGGER.error(e.inspect)
              LOGGER.error(e.backtrace.join("\n"))
            end
          end
        end
        return false
      end


      def create_index(realm)
        index = index_name(realm)
        predefined_mappings = predefined_mappings_for(realm)
        predefined_settings = predefined_settings_for(realm)
        begin
          Pebblebed::Http.put("#{root_url}/#{index}", predefined_settings || default_index_config)
          # Some use-cases require predefined mappings.
          # E.g. we don't want a UID to be string-tokenized because this
          # will cause dash to look like a whitespace and thus not return hits on a query
          predefined_mappings.each_pair do |type, mapping|
            es_mapping_url = "#{root_url}/#{index}/_mapping/#{type}"
            Pebblebed::Http.put(es_mapping_url, {type => mapping})
          end
        rescue Pebblebed::HttpError => e
          if LOGGER.respond_to?:exception
            LOGGER.exception(e)
          else
            LOGGER.error(e.inspect)
            LOGGER.error(e.backtrace.join("\n"))
          end
        end
      end


      # Outputs index mapping for debugging purposes
      def mapping(realm, type = nil)
        index = index_name(realm)
        action = type ? "#{type}/_mapping" : '_mapping'
        url = "#{root_url}/#{index}/#{action}"
        begin
          result = Pebblebed::Http.get(url, {}).body
          return JSON.parse(result)
        rescue Pebblebed::HttpError => e
          unless e.message =~ /IndexMissingException/
            puts "missing index #{index}"
          end
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
          LOGGER.error "Unexpected error on GET #{url}"
          raise e
        end
        result
      end


      def index_mapping(realm, thing = nil)
        url = "#{root_url}"
        url << "/#{index_name(realm)}"
        url << "/#{thing}" if thing
        url << "/_mapping"
        begin
          return Pebblebed::Http.get(url, {}).body
        rescue Pebblebed::HttpError => e
          LOGGER.error "Unexpected error on GET #{url}"
          raise e
        end
        {}
      end


      def query(realm, query_obj)
        options = query_obj.to_hash
        index = index_name(realm)
        url = "#{root_url}/#{index}/_search"
        result = nil
        begin
          response = Pebblebed::Http.post(url, options)
          result = JSON.parse(response.body)
        rescue Pebblebed::HttpError => e
          if e.message =~ /IndexMissingException/
            LOGGER.warn "Attempt to query non-existing index: #{url}"
            raise QueryError.new(
              :label => 'index_missing',
              :message => "Index missing. Attempt to query non-existing index #{index}"
            )
          elsif e.message =~ /SearchParseException/
            LOGGER.warn "SearchParseException at #{url} with #{options.inspect}"
            raise QueryError.new(
              :label => 'search_parse_exception',
              :message => "SearchParseException. Please check that your query is well formed. Full error message: #{e.message}"
            )
          else
            if LOGGER.respond_to?:exception
              LOGGER.exception(e)
            else
              LOGGER.error(e.inspect)
              LOGGER.error(e.backtrace.join("\n"))
            end
          end
        end
        result
      end

      # Returns an array of all records in elasticsearch with the same species:realm.*$oid
      # Throws an OldRecordError if incoming record is older than the one indexed
      def matching_records(incoming_record)
        uid_string = incoming_record['uid']
        uid = Pebbles::Uid.new(uid_string)

        query = Sherlock::Query.new({:uid => uid.cache_key}, [uid.realm])
        matching = begin
          Sherlock::Elasticsearch.query(uid.realm, query)
        rescue Sherlock::Elasticsearch::QueryError => e
          return [] if e.label == 'index_missing'
        end
        matching['hits']['hits'].map do |existing_record|
          raise OldRecordError.new(
            :label => 'old_record',
            :message => "Old record. Either version or updated_at field is older than the existing record, wont index."
          ) unless incoming_record_newer?(incoming_record, existing_record['_source'])
          existing_record['_id']
        end.compact
      end


      def incoming_record_newer?(incoming, existing)
        if incoming['version'] && existing['version']
          return incoming['version'] > existing['version']
        end
        if incoming['updated_at'] && existing['updated_at']
          # no choice but to allow records with identical updated_at
          return Time.parse(incoming['updated_at']) >= Time.parse(existing['updated_at'])
        end
        true # no way to tell, let it pass
      end

    end

  end


end
