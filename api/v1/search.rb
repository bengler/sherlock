
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  # Search using :q (the search term), :uid, :limit, :offset, :sort_by and :order
  get '/search/:realm/?:uid?' do |realm, uid|
    limit = params.delete('limit') { 10 }
    offset = params.delete('offset') { 0 }
    term = params.delete('q')

    options = {:uid => uid, :limit => limit, :offset => offset}
    if params['sort_by']
      options[:sort_by] = params.delete('sort_by')
      options[:order] = params.delete('order')
    end

    query = Sherlock::Query.new(term, options)
    begin
      result = Sherlock::Search.query(realm, query)
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{uid}?#{params[:q]} in #{realm} failed. #{e.message}"
    end
    presenter = Sherlock::HitsPresenter.new(result, {:limit => limit, :offset => offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination, :total => presenter.total}
  end

end
