
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  get '/search/:realm/:query' do |realm, query|
    LOGGER.error "BAM!! Search realm #{realm} for #{query}"
    result = Search.perform_query(realm, query)
    pg :hits, :locals => {:hits => result['hits']}
  end

end
