require 'pebblebed'

# Parses a UID and divines which pebble the UID originates from.
module Sherlock

  class UidOriginIdentifier

    class << self

      def grove?(uid)
        !!(uid =~ /^post\.|^post\:/)
      end

      def origami?(uid)
        ['affiliation', 'associate', 'capacity', 'group', 'note', 'organization', 'unit'].each do |klass|
          return true if !!(uid =~ /^#{klass}\.|^#{klass}\:/)
        end
        false
      end

      def dittforslag?(uid)
        Pebblebed::Uid.new(uid).path[0, 19] == 'mittap.dittforslag.'
      end

    end

  end
end