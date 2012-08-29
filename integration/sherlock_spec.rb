require 'spec_helper'
require 'pebblebed'


Thread.abort_on_exception = true

describe Sherlock do

  describe "vital system services are running" do

    specify "rabbitmq is running" do
      rabbitmq_status = `rabbitmqctl status`
      rabbitmq_status.to_s.should match /{pid,\d+}/
    end

    specify "elasticsearch is running" do
      response = Pebblebed::Http.get("http://localhost:9200/")
      JSON.parse(response.body)['status'].should eq 200
    end

  end

  context "posts to river" do

    subject {
      Sherlock::Indexer.new({:name => 'highway_to_hell', :path => 'hell.pitchfork', :klass => 'post.card'})
    }

    let(:river) {
      Pebblebed::River.new
    }

    let(:uid) {
      'post.card:hell.pitchfork$1'
    }

    let(:post) {
      { :event => 'create',
        :uid => uid,
        :attributes => {"document" => {:app => "hot"}}
      }
    }

    after(:each) do
      Sherlock::Search.delete_index('hell')
      river.queue(:name => 'highway_to_hell').purge
    end

    it "finds a created post with query" do
      river.publish(post)
      subject.start
      sleep 1.4
      result = Sherlock::Search.query("hell", "hot")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "udpates an existing post" do
      river.publish(post)
      subject.start
      sleep 1.4
      update_post = {:event => 'update', :uid => uid, :attributes => {"document" => {:app => "lukewarm"}}}
      river.publish(update_post)
      sleep 1.4
      result = Sherlock::Search.query("hell", "hot")
      result['hits']['total'].should eq 0
      result = Sherlock::Search.query("hell", "lukewarm")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "removes index for deleted post" do
      river.publish(post)
      subject.start
      sleep 1.4
      river.publish(post.merge(:event => 'delete'))
      sleep 1.4
      result = Sherlock::Search.query("hell", "hot")
      result['hits']['total'].should eq 0
    end

    it "does not find the post using non-matching query" do
      river.publish(post)
      subject.start
      sleep 1.4
      result = Sherlock::Search.query("hell", "lukewarm")
      result['hits']['total'].should eq 0
    end

  end


end
