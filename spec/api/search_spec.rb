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
    Sherlock::GroveRecord.new(uid, {'document' => 'hot', 'uid' => uid}).to_hash
  }

  let(:another_record) {
    uid = 'post.card:hell.flames.pitchfork$2'
    Sherlock::GroveRecord.new(uid, {'document' => 'hot stuff', 'uid' => uid}).to_hash
  }

  let(:excluded_record) {
    uid = 'post.card:hell.heck.weird$3'
    Sherlock::GroveRecord.new(uid, {'document' => 'warm', 'uid' => uid}).to_hash
  }

  after(:each) do
    Sherlock::Search.delete_index(realm)
  end

  describe "GET /search/:realm/?:uid?" do
    it 'finds existing record' do
      Sherlock::Search.index record
      Sherlock::Search.index another_record
      Sherlock::Search.index excluded_record
      sleep 1.4
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["hot", "hot stuff"]
    end

    it 'delivers empty result set for non-existing index' do
      get "/search/#{realm}", :q => "hot"
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
      end.should eq ['hot stuff']
    end

    xit "evaluate uid" do

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
        Sherlock::Search.index another_record
        sleep 1.4
        get "/search/#{realm}/post.card:hell.*"
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq [{'app' => 'hot'}]
      end

    end

  end

  describe '/search/post.card:hell.*' do
    let(:exact_record) {
      uid = 'post.card:hell.flames$4'
      Sherlock::GroveRecord.new(uid, {'document' => 'hot', 'uid' => uid}).to_hash
    }


    it "works" do
      Sherlock::Search.index record
      Sherlock::Search.index another_record
      Sherlock::Search.index excluded_record
      Sherlock::Search.index exact_record
      sleep 1

      get '/search/post.card:hell.flames'
      query = {
        "query" => {
          "filtered" => {
            "query" => {
              "query_string" => {
                "query" => "hot"
              }
            },
            "filter" => [
              {
                "bool" => {
                  "must" => [
                    {"term" => { "label_0_" => "hell"}},
                    {"term" => { "label_1_" => 'flames'}}
                  ],
                }
              },
              {
                "and" => {
                  "missing" => {
                    "field" => "label_2_"
                  }
                }
              }
            ]
          }
        }
      }

      root_url = "http://localhost:9200"
      url = "#{root_url}/test_hell/_search"
      response = Pebblebed::Http.get(url, {:source => query.to_json})
      result = JSON.parse(response.body)
      result['hits']['hits'].map do |hit|
        hit['_source']['uid']
      end.sort.should eq(["post.card:hell.flames.devil$1", "post.card:hell.flames.pitchfork$2"])
    end

  end

end
