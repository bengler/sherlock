

module Sherlock
  
  class HitsPresenter

    attr_reader :hits

    def initialize(search_result)
      if search_result
        @hits = search_result['hits']['hits'].map do |hit|
          DeepStruct.wrap(hit['_source'])
        end
      end
      @hits ||= []
    end

  end

end