require 'spec_helper'

describe Sherlock::Update do

  let(:payload) {
    {
      'event' => 'create',
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
    {
      'event' => 'create',
      'uid' => 'post.card:hell.trademarks.pitchfork$1',
      'attributes' => {
        'uid' => 'post.card:hell.pitchfork$1',
        'document' => {'app' => 'hot'},
        'paths' => ["hell.trademarks.pitchfork", "hell.tools.pitchfork"],
        'id' => 'post.card:hell.trademarks.pitchfork$1'
      }
    }
  }

  let(:delete_payload) {
    {
      'event' => 'delete',
      'uid' => 'post.card:hell.trademarks.pitchfork$1',
      'attributes' => {
        'uid' => 'post.card:hell.pitchfork$1',
        'document' => {'app' => 'hot'},
        'paths' => ["hell.trademarks.pitchfork"],
        'id' => 'post.card:hell.trademarks.pitchfork$1'
      }
    }
  }

  it "creates an array of tasks from payload" do
    message = Hash[:payload, payload.to_json]
    tasks = Sherlock::Update.new(message).tasks
    tasks.first['action'].should eq 'index'
  end

  it "builds one index record for every path entry in payload" do
    message = Hash[:payload, multipath_payload.to_json]
    tasks = Sherlock::Update.new(message).tasks
    tasks.count.should eq 2
    tasks.first['action'].should eq 'index'
    tasks.first['record']['uid'].should eq 'post.card:hell.trademarks.pitchfork$1'
    tasks.last['record']['uid'].should eq 'post.card:hell.tools.pitchfork$1'
  end

  it "creates unindex tasks for delete events" do
    message = Hash[:payload, delete_payload.to_json]
    tasks = Sherlock::Update.new(message).tasks
    tasks.first['action'].should eq 'unindex'
  end


  context "temporary mittap email address exposure hack" do

    it "doesnt create tasks for mittap.dittforslag updates" do
      dittforslag_payload = {
        'event' => 'create',
        'uid' => 'post:mittap.dittforslag.dont.index$1',
        'attributes' => {}
      }
      message = Hash[:payload, dittforslag_payload.to_json]
      Sherlock::Update.new(message).tasks.should eq []
    end

    it "correctly identifies dittforslag uids" do
      Sherlock::Update.message_is_from_dittforslag('post:mittap.dittforslag.dont.index$1').should be true
      Sherlock::Update.message_is_from_dittforslag('post:some.thing.else.index$1').should be false
    end

  end


end
