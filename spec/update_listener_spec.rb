require 'spec_helper'

describe Sherlock::UpdateListener do

  subject {
    Sherlock::UpdateListener.new
  }

  let(:realm) {
    'hell'
  }

  let(:payload) {
    { 'event' => 'create',
      'uid' => 'post.card:hell.pitchfork$1',
      'attributes' => {
        'uid' => 'post.card:hell.pitchfork$1',
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
        'uid' => 'post.card:hell.tools.pitchfork$1',
        'document' => {'app' => 'hot'},
        'paths' => ["hell.trademarks.pitchfork", "hell.tools.pitchfork"],
        'id' => 'post.card:hell.tools.pitchfork$1'
      }
    }
  }


  after(:each) do
    Sherlock::Elasticsearch.delete_index(realm)
  end

  it "builds an index record from payload" do
    expected_record =  {"document.app"=>"hot", "paths" => ["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "restricted" => false, "uid"=>"post.card:hell.pitchfork$1", "pristine"=>payload['attributes']}
    subject.build_index_records(payload).first.should eq expected_record
  end

  it "builds one index record for every path entry in payload" do
    first_expected_record =  {"document.app"=>"hot", "paths"=>["hell.trademarks.pitchfork", "hell.tools.pitchfork"], "id"=>"post.card:hell.tools.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"trademarks", "label_2_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "restricted" => false, "uid"=>"post.card:hell.trademarks.pitchfork$1", "pristine"=>multipath_payload['attributes']}
    last_expected_record =  {"document.app"=>"hot", "paths"=>["hell.trademarks.pitchfork", "hell.tools.pitchfork"], "id"=>"post.card:hell.tools.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"tools", "label_2_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "restricted" => false, "uid"=>"post.card:hell.tools.pitchfork$1", "pristine"=>multipath_payload['attributes']}
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
      query = Sherlock::Query.new(:q => "hot")
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_source']['pristine'].should eq payload['attributes']
    end

  end

  context 'index a post with multiple paths' do

    after(:each) do
      Sherlock::Elasticsearch.delete_index(realm)
    end

    it 'indexes every path entry' do
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new(:q => "hot")
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 2
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.trademarks.pitchfork$1'
      result['hits']['hits'].last['_id'].should eq 'post.card:hell.tools.pitchfork$1'
    end

    it "deletes those not mentioned and updates the rest" do
      multipath_payload['attributes']['paths'] << "hell.icons.pitchfork"
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new(:uid => 'post.card:hell.*$1')
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 3
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.trademarks.pitchfork$1'

      multipath_payload['attributes']['paths'] = ["hell.tools.pitchfork"]
      multipath_payload['event'] = 'update'
      message = Hash[:payload, multipath_payload.to_json]
      subject.consider message
      sleep 1.4
      query = Sherlock::Query.new(:uid => 'post.card:hell.*$1')
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq 'post.card:hell.tools.pitchfork$1'
    end

  end

  context "temporary mittap email address exposure hack" do

    it "doesnt index content from mittap.dittforslag" do

      Sherlock::Elasticsearch.create_index('mittap')

      dittforslag_payload = {
        'event' => 'create',
        'uid' => 'post:mittap.dittforslag.dont.index$1',
        'attributes' => {
          'uid' => 'post:mittap.dittforslag.dont.index$1',
          'document' => {'email' => 'secret@dna.no'},
          'paths' => ['mittap.dittforslag.dont.index'],
          'id' => 'post:mittap.dittforslag.dont.index$1'
        }
      }

      message = Hash[:payload, dittforslag_payload.to_json]
      subject.consider message
      sleep 1.4

      query = Sherlock::Query.new(:q => 'secret@dna.no')
      result = Sherlock::Elasticsearch.query('mittap', query)
      result['hits']['total'].should eq 0

      query = Sherlock::Query.new(:uid => 'post:mittap.dittforslag.*$1')
      result = Sherlock::Elasticsearch.query('mittap', query)
      result['hits']['total'].should eq 0
    end

    it "correctly identifies dittforslag uids" do
      subject.message_is_from_dittforslag('post:mittap.dittforslag.dont.index$1').should be true
      subject.message_is_from_dittforslag('post:something.else.dont.index$1').should be false
    end

  end



  context "restricted content" do

    let(:restricted_payload) {
      { 'event' => 'create',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'secret' => 'stuff'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'restricted' => true
        }
      }
    }

    let(:unrestricted_payload) {
      { 'event' => 'create',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'unsecret' => 'stuff'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'restricted' => false
        }
      }
    }

    it "does not return restricted content" do
      message = Hash[:payload, restricted_payload.to_json]
      subject.consider message
      sleep 1.4

      query = Sherlock::Query.new(:uid => 'post.card:hell.*')
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 0

      query = Sherlock::Query.new(:q => "stuff")
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 0
    end

    it "returns unrestricted content" do
      message = Hash[:payload, unrestricted_payload.to_json]
      subject.consider message
      sleep 1.4

      query = Sherlock::Query.new(:uid => 'post.card:hell.*')
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 1

      query = Sherlock::Query.new(:q => "stuff")
      result = Sherlock::Elasticsearch.query(realm, query)
      result['hits']['total'].should eq 1
    end

  end


end
