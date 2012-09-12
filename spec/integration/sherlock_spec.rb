require 'spec_helper'
require 'pebblebed'
require 'api/v1'
require 'rack/test'

Thread.abort_on_exception = true

class TestSherlockV1 < SherlockV1; end

describe Sherlock do

  describe "vital system services are running" do

    specify "rabbitmq is running" do
      rabbitmq_status = `rabbitmqctl status`
      rabbitmq_status.to_s.should match /{pid,\d+}/
    end

    specify "elasticsearch is running" do
      response = Pebblebed::Http.get(Sherlock::Search.root_url)
      JSON.parse(response.body)['status'].should eq 200
    end

  end

  context "posts to river" do

    include Rack::Test::Methods

    def app
      TestSherlockV1
    end


    subject {
      Sherlock::Indexer.new({:name => 'highway_to_hell', :path => 'hell.pitchfork', :klass => 'post.card'})
    }

    let(:realm) {
      'hell'
    }

    let(:river) {
      Pebblebed::River.new
    }

    let(:uid) {
      'post.card:hell.tools.pitchfork$1'
    }

    let(:post) {
      { :event => 'create',
        :uid => uid,
        :attributes => {
          :uid => uid,
          :document => {:app => "hot"},
          :paths => ["hell.tools.pitchfork"]
        }
      }
    }

    after(:each) do
      Sherlock::Search.delete_index(realm)
      river.queue(:name => 'highway_to_hell').purge
      river.queue(:name => 'sherlock.index').purge
      river.queue(:name => 'river.index').purge
    end


    it "finds a created post with query" do
      river.publish(post)
      subject.start
      sleep 1.4

      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['total'].should eq 1
      result['pagination'].should_not eq nil
      result['hits'].first['hit']['uid'].should eq uid
      result['hits'].first['hit']['paths'].count.should eq 1
    end

    it "udpates an existing post" do
      river.publish(post)
      subject.start
      sleep 1.4
      update_post = {
        :event => 'update',
        :uid => uid,
        :attributes => {"document" => {:app => "lukewarm"}, :paths => ["hell.tools.pitchfork"]}
      }
      river.publish(update_post)
      sleep 1.4
      result = Sherlock::Search.query("hell", :q => "hot")
      result['hits']['total'].should eq 0
      result = Sherlock::Search.query("hell", :q => "lukewarm")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "removes index for deleted post" do
      river.publish(post)
      subject.start
      sleep 1.4
      river.publish(post.merge(:event => 'delete'))
      sleep 1.4
      result = Sherlock::Search.query("hell", :q => "hot")
      result['hits']['total'].should eq 0
    end

    it "does not find the post using non-matching query" do
      river.publish(post)
      subject.start
      sleep 1.4
      result = Sherlock::Search.query("hell", :q => "lukewarm")
      result['hits']['total'].should eq 0
    end

  end


end
