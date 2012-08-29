require "spec_helper"
require 'api/v1'
require 'rack/test'

class TestSherlockV1 < SherlockV1; end

describe 'API v1 search' do

  include Rack::Test::Methods

  def app
    TestSherlockV1
  end


  describe "GET /search/:realm/:uid?" do

    let(:realm) {
      'hell'
    }

    let(:uid) {
      'post.card:hell.pitchfork$1'
    }

    let(:record) {
      {'document' => {'app' => 'hot'}, 'realm' => realm, 'uid' => uid}
    }

    let(:another_record) {
      {'document' => {'app' => 'hot stuff'}, 'realm' => realm, 'uid' => 'post.card:hell.pitchfork$2'}
    }

    after(:each) do
      Sherlock::Search.delete_index(realm)
    end

    it 'finds existing record' do
      Sherlock::Search.index record
      Sherlock::Search.index another_record
      sleep 1.4
      get "/search/#{realm}/", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq [{'app' => 'hot'}, {'app' => 'hot stuff'}]
    end

    it 'delivers empty result set for non-existing index' do
      get "/search/#{realm}/", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].should eq []
    end

    it "honors limit and offset" do
      Sherlock::Search.index record
      Sherlock::Search.index another_record
      sleep 1.4
      get "/search/#{realm}/", :q => "hot", :limit => 1, :offset => 1
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq [{'app' => 'hot stuff'}]
    end

    context "evaluate uid" do

      it "ignores complete wildcard uid" do
        Sherlock::Search.index record
        sleep 1.4
        get "/search/#{realm}/*:*", :q => "hot"
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq [{'app' => 'hot'}]
      end

      it "finds a post based on uid" do
        Sherlock::Search.index record
        sleep 1.4
        get "/search/#{realm}/post.card:hell.*"
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq [{'app' => 'hot'}]
      end

    end

  end

end
