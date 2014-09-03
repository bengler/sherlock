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
      'updated_at' => '2014-08-06T10:46:31+0200',
      'document.app' => 'hot',
      'document.updated_at' => '2014-08-06T10:46:31+0200',
      'paths' => ['hell.pitchfork'],
      'id' => 'post.card:hell.pitchfork$1',
      'klass_0_' => 'post',
      'klass_1_' => 'card',
      'label_0_' => 'hell',
      'label_1_' => 'pitchfork',
      'oid_' => '1',
      'realm' => 'hell',
      'version' => 1000,
      'pristine' => {
        'uid' => 'post.card:hell.pitchfork$1',
        'document' => {'app' => 'hot', 'updated_at' => '2014-08-06T10:46:31+0200'},
        'version' => 1000,
        'paths' => ['hell.pitchfork'],
        'id' => 'post.card:hell.pitchfork$1'
      },
      'restricted' => false}
  }

  let(:unversioned_record) {
    {
      'uid' => 'post.card:hell.pitchfork$1',
      'updated_at' => '2014-08-06T10:46:31+0200',
      'document.app' => 'hot',
      'document.updated_at' => '2014-08-06T10:46:31+0200',
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
        'document' => {'app' => 'hot', 'updated_at' => '2014-08-06T10:46:31+0200'},
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


  it 'has the correct ES instance url' do
    Sherlock::Elasticsearch.root_url.should eq 'http://localhost:9200'
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

  it "raises the correct error on querying a non-existing index" do
    query = Sherlock::Query.new(:q => 'hot')
    non_existing_realm = 'unknown_realmzor'
    begin
      Sherlock::Elasticsearch.query(non_existing_realm, query)
    rescue Sherlock::Elasticsearch::QueryError => e
      e.label.should eq 'index_missing'
      e.message.should include non_existing_realm
    end
  end

  it "raises the correct error on a malformed query" do
    query = Sherlock::Query.new(:fields => {'document.updated_at' => '\\34'})
    begin
      Sherlock::Elasticsearch.query(realm, query)
    rescue Sherlock::Elasticsearch::QueryError => e
      e.label.should eq 'search_parse_exception'
      e.message.should include 'Please check that your query is well formed'
      e.message.should include 'IllegalArgumentException[Invalid format'
    end
  end


  context 'indexing old versions' do

    it "raises an error if version is older" do
      old_record = {
        'document' => {'app' => 'lukewarm'},
        'realm' => realm,
        'uid' => uid,
        'version' => 999,
        'restricted' => false
      }
      begin
        Sherlock::Elasticsearch.matching_records(old_record)
      rescue Sherlock::Elasticsearch::OldRecordError => e
        e.label.should eq 'old_record'
        e.message.should include 'Old record'
      end
    end

    it "raises an error if version field is missing and updated_at is older" do
      Sherlock::Elasticsearch.unindex record['uid']
      sleep 1.4
      Sherlock::Elasticsearch.index unversioned_record
      old_unversioned_record = unversioned_record
      old_unversioned_record['updated_at'] = '2013-01-01T12:00:00+0200'
      begin
        Sherlock::Elasticsearch.matching_records(old_unversioned_record)
      rescue Sherlock::Elasticsearch::OldRecordError => e
        e.label.should eq 'old_record'
        e.message.should include 'Old record'
      end
    end

  end



end
