require 'spec_helper'

describe Sherlock::Indexer do

  subject {
    Sherlock::Indexer.new
  }

  let(:realm) {
    'hell'
  }

  let(:payload) {
    { 'event' => 'create',
      'uid' => 'post.card:hell.pitchfork$1',
      'attributes' => {
        'document' => {'app' => 'hot'},
        'paths' => ['hell.pitchfork'],
        'id' => 'post.card:hell.pitchfork$1'
      }
    }
  }

  let(:multipath_payload) {
    { 'event' => 'create',
      'uid' => 'post.card:hell.tools.pitchfork$1',
      'attributes' => {
        'document' => {'app' => 'hot'},
        'paths' => ["hell.trademarks.pitchfork", "hell.tools.pitchfork"],
        'id' => 'post.card:hell.tools.pitchfork$1'
      }
    }
  }


  it "builds an index record from payload" do
    expected_record =  {"document.app"=>"hot", "paths" => ["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1", "pristine"=>payload['attributes']}
    subject.build_index_records(payload).first.should eq expected_record
  end

  it "builds one index record for every path entry in payload" do
    first_expected_record =  {"document.app"=>"hot", "paths"=>["hell.trademarks.pitchfork", "hell.tools.pitchfork"], "id"=>"post.card:hell.tools.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"trademarks", "label_2_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "uid"=>"post.card:hell.trademarks.pitchfork$1", "pristine"=>multipath_payload['attributes']}
    last_expected_record =  {"document.app"=>"hot", "paths"=>["hell.trademarks.pitchfork", "hell.tools.pitchfork"], "id"=>"post.card:hell.tools.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"tools", "label_2_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "uid"=>"post.card:hell.tools.pitchfork$1", "pristine"=>multipath_payload['attributes']}
    records = subject.build_index_records(multipath_payload)
    records.count.should eq 2
    records.first.should eq first_expected_record
    records.last.should eq last_expected_record
  end

  context 'index a post' do

    it 'returns the conserved original document' do
      message = Hash[:payload, payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new("hot")
      result = Sherlock::Search.query(realm, :source => query.to_json)
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_source']['pristine'].should eq payload['attributes']
    end

  end

  context 'index a post with multiple paths' do

    after(:each) do
      Sherlock::Search.delete_index(realm)
    end

    it 'indexes every path entry' do
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new("hot")
      result = Sherlock::Search.query(realm, :source => query.to_json)
      result['hits']['total'].should eq 2
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.trademarks.pitchfork$1'
      result['hits']['hits'].last['_id'].should eq 'post.card:hell.tools.pitchfork$1'
    end

    it "deletes those not mentioned and updates the rest" do
      multipath_payload['attributes']['paths'] << "hell.icons.pitchfork"
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new(nil, :uid => 'post.card:hell.*$1')
      result = Sherlock::Search.query(realm, :source => query.to_json)
      result['hits']['total'].should eq 3
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.trademarks.pitchfork$1'

      multipath_payload['attributes']['paths'] = ["hell.tools.pitchfork"]
      multipath_payload['event'] = 'update'
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new(nil, :uid => 'post.card:hell.*$1')
      result = Sherlock::Search.query(realm, :source => query.to_json)
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.tools.pitchfork$1'
    end

  end

end
