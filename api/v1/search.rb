
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  get '/search/:realm/:query' do |realm, query|
    result = nil
    begin
      result = Sherlock::Search.perform_query(realm, query)
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{query} in #{realm} failed. #{e.message}"
    end
    pg :hits, :locals => {:hits => Sherlock::HitsPresenter.new(result).hits}
  end

end
