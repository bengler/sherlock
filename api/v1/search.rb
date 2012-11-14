
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
  end

  helpers do
    def god_mode?
      current_identity && current_identity.respond_to?(:god) && current_identity.god
    end

    def valid_query?(uid)
      return true unless uid
      begin
        Pebbles::Uid.query(uid)
        return true
      rescue StandardError => e
        return false
      end
    end
  end

  # @apidoc
  # Search indexed data.
  #
  # @description Search indexed data using various parameters. As in all pebbles data is scoped by realm.
  # @note Documents with restricted=true is only accessible by god sessions.
  # @category Sherlock/Search
  # @path /api/sherlock/v1/search/:realm/:uid
  # @http GET
  # @example /api/sherlock/v1/search/apdm/post.greeting:apdm.lifeloop.oa.*
  # @required [String] realm Name of realm containing the searchable data.
  # @optional [String] uid uid denoting a resource, or a wildcard uid indicating a collection of resources.
  # @optional [String] q Query string.
  # @optional [Integer] limit Maximum number of returned hits. Defaults to 10.
  # @optional [Integer] offset Index of the first returned hit. Defaults to 0.
  # @optional [String] sort_attribute Attribute to sort the result set by. Defaults to an internally calculated relevancy score.
  # @optional [String] order Order in which to sort the returned hits. Defaults to DESC.
  # @optional [Boolean] show_restricted Flag denoting whether the results can contain restricted hits. Defaults to false. Passing true requires a god session.
  # @optional [String] range[attribute] Attribute to perform a ranged query by.
  # @optional [String] range[from] Minimum accepted value for a ranged query.
  # @optional [String] range[to] Maximum accepted value for a ranged query.
  # @optional [String] fields[name_of_attribute] Require a named attribute to have a specific value. Use 'null' to indicate a missing value.
  # @status 200 [JSON]
  get '/search/:realm/?:uid?' do |realm, uid|
    halt 403, "Sherlock couldn't parse the UID \"#{uid}\"." unless valid_query?(uid)
    params[:show_restricted] = god_mode?
    query = Sherlock::Query.new(params)
    begin
      result = Sherlock::Elasticsearch.query(realm, query)
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{uid}?#{params[:q]} in #{realm} failed. #{e.message}"
    end
    presenter = Sherlock::HitsPresenter.new(result, {:limit => query.limit, :offset => query.offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination, :total => presenter.total}
  end

end
