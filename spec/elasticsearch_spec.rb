# encoding: utf-8
require 'spec_helper'

describe Sherlock::Elasticsearch do

  let(:realm) {
    'hell'
  }

  let(:uid) {
    'post.card:hell.pitchfork$1'
  }

  let(:record) {
    {
      'uid' => 'post.card:hell.pitchfork$1',
      'document.app' => 'hot',
      'paths' => ['hell.pitchfork'],
      'id' => 'post.card:hell.pitchfork$1',
      'klass_0_' => 'post',
      'klass_1_' => 'card',
      'label_0_' => 'hell',
      'label_1_' => 'pitchfork',
      'oid_' => '1',
      'realm' => 'hell',
      'pristine' => {
        'uid' => 'post.card:hell.pitchfork$1',
        'document' => {'app' => 'hot'},
        'paths' => ['hell.pitchfork'],
        'id' => 'post.card:hell.pitchfork$1'
      },
      'restricted' => false}
  }


  before(:each) do
    Sherlock::Elasticsearch.index record
    sleep 1.4
  end

  after(:each) do
    Sherlock::Elasticsearch.delete_index(realm)
  end


  it "indexes a record and finds it" do
    query = Sherlock::Query.new(:q => "hot")
    result = Sherlock::Elasticsearch.query(realm, query)
    result['hits']['total'].should eq 1
    result['hits']['hits'].first['_id'].should eq uid
  end


  it "does not find something thats not there" do
    query = Sherlock::Query.new(:q => "lukewarm")
    result = Sherlock::Elasticsearch.query(realm, query)
    result['hits']['total'].should eq 0
  end

  it "udpates an existing record" do
    update_record = {'document' => {'app' => 'lukewarm'}, 'realm' => realm, 'uid' => uid, 'restricted' => false}
    Sherlock::Elasticsearch.index update_record
    sleep 1.4
    query = Sherlock::Query.new(:q => "hot")
    result = Sherlock::Elasticsearch.query(realm, query)
    result['hits']['total'].should eq 0
    query = Sherlock::Query.new(:q => "lukewarm")
    result = Sherlock::Elasticsearch.query(realm, query)
    result['hits']['total'].should eq 1
    result['hits']['hits'].first['_id'].should eq uid
  end

  it "removes index for a deleted record" do
    Sherlock::Elasticsearch.unindex record['uid']
    sleep 1.4
    query = Sherlock::Query.new(:q => "hot")
    result = Sherlock::Elasticsearch.query(realm, query)
    result['hits']['total'].should eq 0
  end

  it "deletes the whole index and swallows index missing errors" do
    Sherlock::Elasticsearch.delete_index(realm)
    sleep 1.4
    query = Sherlock::Query.new(:q => "hot")
    lambda { Sherlock::Elasticsearch.query(realm, query) }.should_not raise_error(Pebblebed::HttpError)
  end

  it "creates new indexes with the whitespace tokenizer and the lowercase filter" do
    require 'pebblebed'
    index_name = Sherlock::Elasticsearch.index_name(realm)
    url = "http://localhost:9200/#{index_name}/_analyze"
    text = 'a A 1 is'
    response = Pebblebed::Http.get(url, {:text => text})
    result = JSON.parse(response.body)
    result['tokens'].count.should eq text.split(' ').count
    result['tokens'][0]['token'].should eq text[0]
  end


end
