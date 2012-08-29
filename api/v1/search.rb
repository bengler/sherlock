
class SherlockV1 < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/search.rb'
  end

  get '/search/:realm/:uid?' do |realm, uid|
    limit = params.fetch('limit') { 10 }
    offset = params.fetch('offset') { 0 }
    options = {
      :size => limit,
      :from => offset,
      :q => params[:q]
    }
    options[:uid] = uid if uid && uid != "*:*" # ignore wildcard uids
    result = nil
    begin
      result = Sherlock::Search.query(realm, options)
    rescue Pebblebed::HttpError => e
      LOGGER.warn "Search for #{params[:q]} in #{realm} failed. #{e.message}"
    end
    presenter = Sherlock::HitsPresenter.new(result, {:limit => limit, :offset => offset})
    pg :hits, :locals => {:hits => presenter.hits, :pagination => presenter.pagination}
  end

end
