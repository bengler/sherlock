
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  # If a :source parameter is sent in, everything
  # else will be ignored.
  #
  # In all other cases, a query will be built up using
  # the :uid (optional), :q (the search term), and :limit
  # and :offset
  get '/search/:realm/?:uid?' do |realm, uid|
    limit = params.delete('limit') { 10 }
    offset = params.delete('offset') { 0 }
    term = params.delete('q')
    query = params.delete('source')
    query ||= Sherlock::Query.new(term, :uid => uid, :limit => limit, :offset => offset).to_json
    begin
      result = Sherlock::Search.query(realm, :source => query)
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{uid}?#{params[:q]} in #{realm} failed. #{e.message}"
    end
    presenter = Sherlock::HitsPresenter.new(result, {:limit => limit, :offset => offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination}
  end

end
