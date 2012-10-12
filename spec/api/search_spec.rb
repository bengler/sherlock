require "spec_helper"
require 'api/v1'
require 'rack/test'

class TestSherlockV1 < SherlockV1; end

describe 'API v1 search' do

  include Rack::Test::Methods

  def app
    TestSherlockV1
  end

  let(:realm) {
    'hell'
  }

  let(:record) {
    uid = 'post.card:hell.flames.devil$1'
    Sherlock::Parsers::Grove.new(uid, {'document' => 'hot', 'uid' => uid}).to_hash
  }

  let(:another_record) {
    uid = 'post.card:hell.flames.pitchfork$2'
    Sherlock::Parsers::Grove.new(uid, {'document' => 'hot stuff', 'uid' => uid}).to_hash
  }

  let(:excluded_record) {
    uid = 'post.card:hell.heck.weird$3'
    Sherlock::Parsers::Grove.new(uid, {'document' => 'warm', 'uid' => uid}).to_hash
  }

  after(:each) do
    Sherlock::Elasticsearch.delete_index(realm)
  end

  describe "GET /search/:realm/?:uid?" do
    it 'finds existing record' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 1.4
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["hot", "hot stuff"]
      result['hits'].first['hit']['uid'].should eq "post.card:hell.flames.devil$1"
    end

    it 'delivers empty result set for non-existing index' do
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].should eq []
    end

    it "honors limit and offset" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      sleep 1.4
      get "/search/#{realm}", :q => "hot", :limit => 1, :offset => 1
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ['hot stuff']
    end

    context "sorting results " do

      let(:record) {
        uid = 'post.card:hell.flames.bbq$1'
        Sherlock::Parsers::Grove.new(uid, { 'document' => {'item' => 'first bbq', 'start_time' => '2012-08-23T17:00:00+02:00'}, 'uid' => uid}).to_hash
      }

      let(:another_record) {
        uid = 'post.card:hell.flames.wtf.bbq$2'
        Sherlock::Parsers::Grove.new(uid, { 'document' => {'item' => 'second bbq', 'start_time' => '2012-08-24T17:00:00+02:00'}, 'uid' => uid}).to_hash
      }

      it "sorts by timestamp on correct order" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        sleep 1.4
        get "/search/#{realm}", :q => "bbq", :sort_by => "start_time", :order => 'asc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].first['hit']['document']['item'].should eq 'first bbq'

        get "/search/#{realm}", :q => "bbq", :sort_by => "start_time", :order => 'desc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].first['hit']['document']['item'].should eq 'second bbq'
      end

    end
  end

  describe '/search/post.card:hell.*' do
    it "works" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 1

      get "/search/#{realm}/post.card:hell.flames.*", :q => "hot"

      result = JSON.parse(last_response.body)

      result['hits'].map do |hit|
        hit['hit']['uid']
      end.sort.should eq(["post.card:hell.flames.devil$1", "post.card:hell.flames.pitchfork$2"])
    end

  end

  describe '/search/realm/fulluid' do
    it "works" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      sleep 1

      uid = 'post.card:hell.flames.devil$1'
      get "/search/#{realm}/#{uid}", :q => 'hot'

      result = JSON.parse(last_response.body)

      result['hits'].map do |hit|
        hit['hit']['uid']
      end.sort.should eq([uid])
    end
  end

  describe '/search/realm/'
end
