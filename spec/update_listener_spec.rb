require 'spec_helper'

describe Sherlock::UpdateListener do

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

  it "makes stuff happen in Elasticsearch" do
    message = Hash[:payload, payload.to_json]
    Sherlock::Elasticsearch.should_receive(:index)
    Sherlock::UpdateListener.new.consider message
  end

end
