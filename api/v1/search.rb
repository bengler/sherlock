
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
  end

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
  # @optional [String] sort_by Document attribute (don't prefix with 'document.') to sort the result set by. Defaults to an internally calculated relevancy score. Seperate multiple fields with comma.
  # @optional [String] order Order in which to sort the returned hits. Defaults to DESC. Supports multiple fields sorting with individual order by seperating by comma in the same order as sort_by.
  # @optional [String] range[attribute] Attribute to perform a ranged query by. DEPRECATED, use to/from.
  # @optional [String] range[from] Minimum accepted value for a ranged query. DEPRECATED, use to/from.
  # @optional [String] range[to] Maximum accepted value for a ranged query. DEPRECATED, use to/from.
  # @optional [String] min[name_of_attribute] Minimum accepted value for a ranged query.
  # @optional [String] max[name_of_attribute] Maximum accepted value for a ranged query.
  # @optional [String] fields[name_of_attribute] Require a named attribute to have a specific value. Use "null" to indicate a missing value. Use 'value1|value2' to indicate 'or'.
  # @optional [String] deleted How to treat the deleted attribute. Accepts 'include' or 'only'. Default is to not include these records. Getting a deleted record requires access to its path.
  # @status 200 JSON
  get '/search/:realm/?:uid?' do |realm, uid|
    halt 403, "Sherlock couldn't parse the UID \"#{uid}\"." unless valid_uid_query? uid
    ['offset', 'limit'].each do |param|
      halt 400, "#{param} must be an integer" if params[param] && !is_integer?(params[param])
    end

    query_path = uid ? Pebbles::Uid.query(uid).path : nil
    query = Sherlock::Query.new(params, accessible_paths(query_path))

    result = Sherlock::Elasticsearch.query(realm, query)
    result = Sherlock::ResultCensor.consider(result, god_mode?, current_identity_id)

    presenter = Sherlock::HitsPresenter.new(result, {:limit => query.limit, :offset => query.offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination, :total => presenter.total}
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
