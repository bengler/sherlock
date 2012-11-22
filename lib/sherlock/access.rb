# Generates a filter for elasticsearch that makes the results respect the Pebbles Security Model
module Sherlock

  class Access
    # Cache for a short time, because when the login status changes, it may take up to this
    # amount of seconds until the security situation of the user at the keyboard is updated.
    IDENTITY_CACHE_TTL = 2*60


    def self.accessible_paths(connector, identity_id, wildcard_path = nil)
      access_data = fetch_access_data(identity_id, connector)
      result = access_data.relevant_subtrees(wildcard_path || '') if access_data
      result || []
    end

    # Returns a Pebblebed::Security::AccessData object for the current user
    def self.fetch_access_data(identity_id, connector)
      return nil unless identity_id
      Pebblebed::Security::Client.new(connector).access_data_for(identity_id)
    end
  end
end