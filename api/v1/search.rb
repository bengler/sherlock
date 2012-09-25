
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  # Search using :q (the search term), :uid, :limit, :offset, :sort_by and :order
  get '/search/:realm/?:uid?' do |realm, uid|
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
