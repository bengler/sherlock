require 'spec_helper'

describe Sherlock::UpdateListener do

  context 'indexing' do

    let(:payload) {
      { 'event' => 'update',
        'uid' => 'post.card:hell.pitchfork$1',
        'attributes' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1'
        }
      }
    }

    it "works" do
      message = Hash[:payload, payload.to_json]
      Sherlock::Elasticsearch.should_receive(:index)
      Sherlock::UpdateListener.new.consider message
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
      message = Hash[:payload, payload.to_json]
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      Sherlock::UpdateListener.new.consider message
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
      message = Hash[:payload, payload.to_json]
      expected = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_not_receive(:unindex).with('post.card:hell.pitchfork$1')
      Sherlock::Elasticsearch.should_receive(:index).with(expected)
      Sherlock::UpdateListener.new.consider message
    end

    it 'does not index non-soft_deleted records' do
      p = payload
      p['soft_deleted'] = false
      message = Hash[:payload, p.to_json]
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      Sherlock::UpdateListener.new.consider message

      p.delete('soft_deleted')
      message = Hash[:payload, p.to_json]
      Sherlock::Elasticsearch.should_receive(:unindex).with('post.card:hell.pitchfork$1')
      Sherlock::UpdateListener.new.consider message
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
      message = Hash[:payload, payload.to_json]
      expected = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected)
      Sherlock::UpdateListener.new.consider message
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
      message1 = Hash[:payload, payload.to_json]
      expected1 = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:33:04+02:00", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:33:04+02:00"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected1)
      Sherlock::UpdateListener.new.consider message1

      message2 = Hash[:payload, updated_payload.to_json]
      expected2 = {"uid"=>"post.card:hell.pitchfork$1", "document.app"=>"hot", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:46:51+02:00", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>"post.card:hell.pitchfork$1", "document"=>{"app"=>"hot"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>"post.card:hell.pitchfork$1", "updated_at"=>"2014-06-30T10:46:51+02:00"}, "restricted"=>false}
      Sherlock::Elasticsearch.should_receive(:index).with(expected2)
      Sherlock::UpdateListener.new.consider message2
    end

  end


end
