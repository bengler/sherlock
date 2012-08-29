
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  get '/search/:realm/:query' do |realm, query|
    limit = params.fetch('limit') { 10 }
    offset = params.fetch('offset') { 0 }
    result = nil
    begin
      result = Sherlock::Search.query(realm, query, {:size => limit, :from => offset})
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{query} in #{realm} failed. #{e.message}"
    end
    presenter = Sherlock::HitsPresenter.new(result, {:limit => limit, :offset => offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination}
  end

end
