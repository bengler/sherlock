

module Sherlock
  
  class HitsPresenter

    attr_reader :hits, :pagination

    def initialize(search_result, pagination_options)
      if search_result
        @hits = search_result['hits']['hits'].map do |hit|
          DeepStruct.wrap(hit['_source'])
        end
        total = search_result['hits']['total']
      else
        @hits = []
        total = 0
      end
      @pagination = Pagination.new(pagination_options[:limit], pagination_options[:offset], total)
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
