

module Sherlock

  class HitsPresenter

    attr_reader :hits, :pagination, :total

    def initialize(search_result, pagination_options, include_score = true)
      if search_result
        @hits = search_result['hits']['hits'].compact.map do |hit|
          hit_hash = hit['_source']['pristine'].merge({'uid' => hit['_id']})
          hit_hash = hit_hash.merge({'score' => hit['_score']}) if include_score
          DeepStruct.wrap(hit_hash)
        end
        @total = search_result['hits']['total']
      else
        @hits = []
        @total = 0
      end
      @pagination = Pagination.new(pagination_options[:limit], pagination_options[:offset], @total)
    end


    class Pagination

      attr_reader :limit, :offset, :last_page

      def initialize(limit, offset, total)
        @limit = limit.to_i
        @offset = offset.to_i
        @last_page = @offset >= total - @limit
      end

    end

  end

end
