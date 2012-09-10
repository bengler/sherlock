# encoding: utf-8
require 'spec_helper'

describe Sherlock::Search do

  let(:realm) {
    'hell'
  }

  let(:uid) {
    'post.card:hell.pitchfork$1'
  }

  let(:record) {
    {'document' => {'app' => 'hot'}, 'realm' => realm, 'uid' => uid}
  }


  before(:each) do
    Sherlock::Search.index record
    sleep 1.4
  end

  after(:each) do
    Sherlock::Search.delete_index(realm)
  end


  context "using the Query class" do

    it "indexes a record and finds it" do
      query = Sherlock::Query.new("hot").to_json
      result = Sherlock::Search.query(realm, :source => query)
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

  end

  context "passing an options hash directly to Search" do

    it "indexes a record and finds it" do
      result = Sherlock::Search.query(realm, :q => "hot")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "does not find something thats not there" do
      result = Sherlock::Search.query(realm, :q => "lukewarm")
      result['hits']['total'].should eq 0
    end

    it "udpates an existing record" do
      update_record = {'document' => {'app' => 'lukewarm'}, 'realm' => realm, 'uid' => uid}
      Sherlock::Search.index update_record
      sleep 1.4
      result = Sherlock::Search.query(realm, :q => "hot")
      result['hits']['total'].should eq 0
      result = Sherlock::Search.query(realm, :q => "lukewarm")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "removes index for a deleted record" do
      Sherlock::Search.unindex record['uid']
      sleep 1.4
      result = Sherlock::Search.query(realm, :q => "hot")
      result['hits']['total'].should eq 0
    end

    it "deletes the whole index and swallows index missing errors" do
      Sherlock::Search.delete_index(realm)
      sleep 1.4
      lambda { Sherlock::Search.query(realm, :q => "hot") }.should_not raise_error(Pebblebed::HttpError)
    end

  end

end
