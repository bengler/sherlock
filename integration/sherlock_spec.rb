require 'sherlock'
require 'search'
require 'pebblebed'
ENV['RACK_ENV'] ||= 'test'


Thread.abort_on_exception = true

describe Sherlock do

  indexer_options = {:name => 'highway_to_hell', :path => 'hell.pitchfork|realm.stuff', :klass => 'post.card'}

  subject {
    Sherlock.new
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

  before(:each) do
    Sherlock.environment = 'test'
    Sherlock.config
    river.queue(:name => 'highway_to_hell').purge
  end

  after(:each) do
    #Search.delete_entire_index('hell')
    river.queue(:name => 'highway_to_hell').purge
  end


  context "posts to river" do

    it "finds a created post with query" do
      river.publish(post)
      subject.run(indexer_options)
      sleep 1.4
      result = Search.perform_query("hell", "hot")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "udpates an existing post" do
      river.publish(post)
      subject.run(indexer_options)
      sleep 1.4
      update_post = {:event => 'update', :uid => uid, :attributes => {"document" => {:app => "lukewarm"}}}
      river.publish(update_post)
      sleep 1.4
      result = Search.perform_query("hell", "lukewarm")
      result['hits']['total'].should eq 1
      result['hits']['hits'].first['_id'].should eq uid
    end

    it "removes index for deleted post" do
      river.publish(post)
      subject.run(indexer_options)
      sleep 1.4
      river.publish(post.merge(:event => 'delete'))
      sleep 1.4
      result = Search.perform_query("hell", "hot")
      result['hits']['total'].should eq 0
    end

    it "does not find the post using non-matching query" do
      river.publish(post)
      subject.run(indexer_options)
      sleep 1.4
      result = Search.perform_query("hell", "lukewarm")
      result['hits']['total'].should eq 0
    end

  end


end
