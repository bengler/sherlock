
module Sherlock

  # This class reviews a search result and performs censorship as neccessary
  class ResultCensor

      def self.consider(search_result, god_mode, user_identity)
        return unless search_result
        return search_result if god_mode
        search_result['hits']['hits'].each do |hit|
          unless user_identity && user_identity == hit['_source']['created_by']
            hit['_source']['pristine'].delete('sensitive')
            hit['_source'].each_pair do |key, value|
              hit['_source'].delete(key) if key.start_with? 'sensitive.'
            end
          end
        end
        search_result
      end

  end
end
