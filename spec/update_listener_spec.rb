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


end
