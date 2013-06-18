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
          'id' => 'post.card:hell.pitchfork$1',
          'published' => true
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


end
