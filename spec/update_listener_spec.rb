require 'spec_helper'

describe Sherlock::UpdateListener do

  subject {
    Sherlock::UpdateListener.new
  }

  context 'indexing' do

    after(:each) do
      Sherlock::Elasticsearch.delete_index('hell')
    end


    let(:payload) {
      { 'event' => 'update',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'updated_at' => '2014-06-30T10:46:51+02:00'
        }
      }
    }

    it "works" do
      Sherlock::Elasticsearch.should_receive(:index)
      subject.consider payload
    end

    it "wont index an older record" do
      versioned_payload = {}.merge(payload)
      versioned_payload['attributes']['version'] = 1000
      Sherlock::Elasticsearch.should_receive(:index).and_call_original
      subject.consider(versioned_payload)
      sleep 1.4
      old_versioned_payload = {}.merge(payload)
      old_versioned_payload['attributes']['version'] = 999
      Sherlock::Elasticsearch.should_not_receive(:index)
      subject.consider(old_versioned_payload)
    end

    it "will index an newer record" do
      versioned_payload = {}.merge(payload)
      versioned_payload['attributes']['version'] = 1000
      Sherlock::Elasticsearch.should_receive(:index).and_call_original
      subject.consider(versioned_payload)

      new_versioned_payload = {}.merge(payload)
      new_versioned_payload['attributes']['version'] = 1001
      Sherlock::Elasticsearch.should_receive(:index)
      subject.consider(new_versioned_payload)
    end

  end

  context 'unindexing' do

    let(:payload) {
      { 'event' => 'update',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'published' => false
        }
      }
    }

    it 'works' do
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      subject.consider payload
    end

  end

  context 'indexing soft_deleted records' do

    let(:payload) {
      { 'event' => 'delete',
        'uid' => 'post.card:hell.pitchfork$1',
        'soft_deleted' => true,
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1'
        }
      }
    }

    it 'indexes soft_deleted records' do
      expected = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_not_receive(:unindex).with('post.card:hell.pitchfork$1')
      Sherlock::Elasticsearch.should_receive(:index).with(expected)
      subject.consider payload
    end

    it 'does not index non-soft_deleted records' do
      p = payload
      p['soft_deleted'] = false
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      subject.consider p

      p.delete('soft_deleted')
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      subject.consider p
    end

  end

  context 'indexing the protected field' do

    let(:payload) {
      { 'event' => 'create',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'protected' => {'price' => 'expensive'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1'
        }
      }
    }

    it 'works' do
      expected = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected)
      subject.consider payload
    end

  end


  context 'no indexing of changed_attributes' do

    let(:payload) {
      { 'event' => 'create',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'protected' => {'price' => 'expensive'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'updated_at' => '2014-06-30T10:33:04+02:00'
        }
      }
    }

    let(:updated_payload) {
      { 'event' => 'update',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'protected' => {'price' => 'expensive'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1',
          'updated_at' => '2014-06-30T10:46:51+02:00'
        },
        'changed_attributes' => {
          "updated_at" => ["2014-06-30T10:33:04+02:00", "2014-06-30T10:46:51+02:00"]
        }
      }
    }

    it 'works' do
      expected1 = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:33:04+02:00", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:33:04+02:00"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected1)
      subject.consider payload

      expected2 = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:46:51+02:00", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:46:51+02:00"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected2)
      subject.consider updated_payload
    end

  end


end
