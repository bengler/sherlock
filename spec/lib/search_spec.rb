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

  after(:each) do
    Sherlock::Search.delete_index(realm)
  end


  it "indexes a record" do
    Sherlock::Search.index record
    sleep 1.4
    result = Sherlock::Search.query(realm, :q => "hot")
    result['hits']['total'].should eq 1
    result['hits']['hits'].first['_id'].should eq uid
  end

  it "does not find something thats not there" do
    Sherlock::Search.index record
    sleep 1.4
    result = Sherlock::Search.query(realm, :q => "lukewarm")
    result['hits']['total'].should eq 0
  end    

  it "udpates an existing record" do
    Sherlock::Search.index record
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
    Sherlock::Search.index record
    sleep 1.4
    Sherlock::Search.unindex record
    sleep 1.4
    result = Sherlock::Search.query(realm, :q => "hot")
    result['hits']['total'].should eq 0
  end

  it "deletes the whole index" do
    Sherlock::Search.index record
    sleep 1.4
    Sherlock::Search.delete_index(realm)
    sleep 1.4
    lambda { Sherlock::Search.query(realm, :q => "hot") }.should raise_error(Pebblebed::HttpError)
  end

end
