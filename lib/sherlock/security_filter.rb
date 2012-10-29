# Generates a filter for elasticsearch that makes the results respect the Pebbles Security Model

module Sherlock
  class SecurityFilter
    # Cache for a short time, because when the login status changes, it may take up to this
    # amount of seconds until the security situation of the user at the keyboard is updated.
    IDENTITY_CACHE_TTL = 2*60

    # Provide a connector configured with the current session_key
    def initialize(connector)
      @connector = connector
      @access_data = fetch_access_data
    end

    # Generates filter terms given a search on the provided wildcard path. If no path given,
    # omit parameter.
    def generate(wildcard_path = nil)
      # Everyone gets to see unrestricted documents
      accept = [{:term => {'restricted' => false}}]
      if @access_data
        # Add terms for each relevant subtree that the current user is allowed privileged access to
        @access_data.relevant_subtrees(wildcard_path || '').each do |path|
          accept << {:terms => Pebblebed::Labels.new(path, :suffix => '').expanded}
        end
      end
      {:filter => {:or => accept}}
    end

    private

    # Determines the current identity through a cache, meaning a user may still access sacred content
    # up to IDENTITY_CACHE_TTL seconds after logging out.
    def determine_identity_id
      return nil unless @connector.key
      result = $memcached.fetch("identity:#{@connector.key}", IDENTITY_CACHE_TTL) do
        identity_record = connector.checkpoint.get('/identities/me')
        (identity_record.id?) ? identity_record.id : 0
      end
      result = nil if result == 0
      result
    end

    def fetch_access_data
      identity_id = determine_identity_id
      return nil unless identity_id
      Pebblebed::Security::Client.new(@connector).access_data_for(determine_identity_id) 
    end
  end
end