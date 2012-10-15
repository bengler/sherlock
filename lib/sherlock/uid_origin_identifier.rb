require 'pebblebed'

module Sherlock

  class UidOriginIdentifier

    class << self

      def checkpoint?(uid)
        # TODO re-implement this when we know the new names of these checkpoint classes
        !!(uid =~ /^group(|_subtree|_membership)(\.|\:)/)
      end

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