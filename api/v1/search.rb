
class SherlockV1 < Sinatra::Base

  ANON_QUERY_TTL = 180

  configure :development do
    register Sinatra::Reloader
  end
  register Sinatra::MultiRoute

  helpers do

    def god_mode?
      current_identity && current_identity.respond_to?(:god) && current_identity.god
    end

    def current_identity_id
      (current_identity && current_identity.id) ? current_identity.id : nil
    end

    def valid_uid_query?(uid)
      return true unless uid
      begin
        Pebbles::Uid.query(uid)
        return true
      rescue StandardError => e
        return false
      end
    end

    def accessible_paths(query_path)
      # Gods can see everything in their realm
      return [current_identity.realm] if god_mode?
      Sherlock::Access.accessible_paths(pebbles, current_identity_id, query_path)
    end


    def handle_search_request(realm, uid)
      content_type 'application/json', :charset => 'utf-8'
      uid ||= params['uid']

      halt 403, {:error => 'invalid_uid', :message => "Sherlock couldn't parse the UID \"#{uid}\"."} unless valid_uid_query? uid

      ['offset', 'limit'].each do |param|
        halt 400, {:error => 'require_integer', :message => "#{param} must be an integer"} if params[param] && !is_integer?(params[param])
      end

      cache_key = request.url
      if current_identity_id || (params['nocache'] == 'true')
        json_result = perform_query(realm, uid)
      else
        json_result = $memcached.fetch(request.url, ANON_QUERY_TTL) do
          perform_query(realm, uid)
        end
      end
      [200, json_result]
    end


    def perform_query(realm, uid)
      params.symbolize_keys!
      uid = clean_up_uid!

      uid_query = uid ? Pebbles::Uid.query(uid) : nil
      query_path = uid_query ? uid_query.path : nil

      clean_up_return_fields!
      ensure_correct_limit!(uid_query)

      query = Sherlock::Query.new(params, accessible_paths(query_path))
      begin
        result = Sherlock::Elasticsearch.query(realm, query)
      rescue Sherlock::Elasticsearch::QueryError => e
        halt 400, {:error => e.label, :message => e.message}.to_json
      end

      result = Sherlock::ResultCensor.consider(result, god_mode?, current_identity_id)
      result = ensure_correct_order(uid_query, result)
      pagination_options = {:limit => query.limit, :offset => query.offset}

      presenter = Sherlock::HitsPresenter.new(result, pagination_options, include_score?)
      locals = {
        :hits => presenter.hits,
        :pagination => presenter.pagination,
        :total => presenter.total
      }
      pg(:hits, :locals => locals)
    end

    # override limit if query contains a list of IDs
    def ensure_correct_limit!(uid_query)
      return unless uid_query && uid_query.list?
      params[:limit] = uid_query.terms.count
    end

    def clean_up_return_fields!
      return unless params[:return_fields]
      params[:return_fields] = params[:return_fields].split(',').compact.uniq.map {|f| f.strip}
    end

    def clean_up_uid!
      return unless params[:uid]
      # substitute two or more pipes next to each other with a single pipe
      params[:uid] = params[:uid].gsub(/(\|)+/, '|')
    end

    def include_score?
      return true unless params[:return_fields]
      params[:return_fields].include?('score')
    end

    # ES result order does not match the queried order. Fixing this right here.
    def ensure_correct_order(uid_query, incoming_result)
      return incoming_result unless uid_query && uid_query.list?
      hits_by_id = Hash[incoming_result['hits']['hits'].map { |hit| [hit['_source']['pristine']['uid'].split('$').last, hit] }] # revamp results for fast retrieval
      ordered_ids = uid_query.terms.map {|term| term.split('$').last} # wanted order
      correctly_ordered_hits = ordered_ids.map { |id| hits_by_id[id] } # hits, ordered
      incoming_result['hits']['hits'] = correctly_ordered_hits # write them back
      incoming_result
    end

  end


  # @apidoc
  # Search indexed data.
  #
  # @description Search indexed data using various parameters. As in all pebbles data is scoped by realm.
  # @note Documents with restricted=true is only accessible by god sessions or users with checkpoint-specified access to that path.
  # @category Sherlock/Search
  # @path /api/sherlock/v1/search/:realm/:uid
  # @http GET
  # @example /api/sherlock/v1/search/apdm/post.greeting:apdm.lifeloop.oa.*
  # @required [String] realm Name of realm containing the searchable data.
  # @optional [String] uid uid denoting a resource, or a wildcard uid indicating a collection of resources.
  # @optional [String] q Query string.
  # @optional [Integer] limit Maximum number of returned hits. Defaults to 10.
  # @optional [Integer] offset Index of the first returned hit. Defaults to 0.
  # @optional [String] sort_by Document attribute to sort the result set by. Defaults to an internally calculated relevancy score. Seperate multiple fields with comma.
  # @optional [String] order Order in which to sort the returned hits. Defaults to DESC. Supports multiple fields sorting with individual order by seperating by comma in the same order as sort_by.
  # @optional [String] range[attribute] Attribute to perform a ranged query by. DEPRECATED, use min/max.
  # @optional [String] range[from] Minimum accepted value for a ranged query. DEPRECATED, use min/max.
  # @optional [String] range[to] Maximum accepted value for a ranged query. DEPRECATED, use min/max.
  # @optional [String] min[name_of_attribute] Minimum accepted value for a ranged query.
  # @optional [String] max[name_of_attribute] Maximum accepted value for a ranged query.
  # @optional [String] fields[name_of_attribute] Require a named attribute to have a specific value. Use "null" to indicate a missing value. Use 'value1|value2' to indicate 'or'.
  # @optional [String] deleted How to treat the deleted attribute. Accepts 'include' or 'only'. Default is to not include these records. Getting a deleted record requires access to its path.
  # @optional [String] unpublished How to treat unpublished records in the result. Accepts 'include' or 'only'. Default is to not include these records. Getting an unpublished record requires access to its path.
  # @optional [Boolean] nocache Bypass cache for guest users. Default is false.
  # @optional [String] return_fields Return only these named fields, separated by comma. E.g. "realm,document.author,updated_at"
  # @status 200 JSON
  get '/search/:realm/?:uid?' do |realm, uid|
    handle_search_request(realm, uid)
  end

  # @apidoc
  # Search indexed data. Same params as the GET endpoint
  #
  # @category Sherlock/Search
  # @path /api/sherlock/v1/search/:realm/:uid
  # @http POST
  # @example /api/sherlock/v1/search/apdm/post.greeting:apdm.lifeloop.oa.*
  # @status 200 JSON
  post '/search/:realm/?:uid?' do |realm, uid|
    handle_search_request(realm, uid)
  end


  # @apidoc
  # Get Elasticsearch mappings.
  #
  # @description Take a look at how Elasticsearch has chosen to index data
  # @category Sherlock/Mapping
  # @path /api/sherlock/v1/mapping/:realm/?:klass?
  # @http GET
  # @example /api/sherlock/v1/mapping/apdm/post.greeting
  # @required [String] realm Name of realm containing the searchable data.
  # @optional [String] klass Name of a specific indexed datatype.
  # @status 200 JSON
  get '/mapping/:realm/?:klass?' do |realm, klass|
    content_type 'application/json'
    json_result = Sherlock::Elasticsearch.index_mapping(realm, klass)

    [200, json_result]
  end


  def is_integer?(string)
    begin
      Integer(string)
      return true
    rescue ArgumentError, TypeError
      false
    end
  end

end
