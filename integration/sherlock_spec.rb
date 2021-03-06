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
      response = Pebblebed::Http.get(Sherlock::Elasticsearch.root_url)
      JSON.parse(response.body)['status'].should eq 200
    end

  end

  let(:guest) { DeepStruct.wrap({}) }
  let(:identity) {guest}
  let(:checkpoint) { stub(:get => identity) }

  before :each do
    Pebblebed::Connector.any_instance.stub(:checkpoint).and_return checkpoint
  end

  describe "Elasticsearch server configuration" do
    let(:record) {
      {
        'uid' => 'post.card:hell.pitchfork$1',
        'document.app' => 'hot',
        'paths' => ['hell.pitchfork'],
        'id' => 'post.card:hell.pitchfork$1',
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'label_0_' => 'hell',
        'label_1_' => 'pitchfork',
        'oid_' => '1',
        'realm' => 'hell',
        'pristine' => {
          'uid' => 'post.card:hell.pitchfork$1',
          'document' => {'app' => 'hot'},
          'paths' => ['hell.pitchfork'],
          'id' => 'post.card:hell.pitchfork$1'
        },
        'restricted' => false}
    }

    before(:each) do
      Sherlock::Elasticsearch.index record
      sleep 1.4
    end

    it "creates new indexes with the whitespace tokenizer and the lowercase filter" do
      require 'pebblebed'
      index_name = Sherlock::Elasticsearch.index_name('hell')
      url = "http://localhost:9200/#{index_name}/_analyze"
      text = 'a A 1 is'
      response = Pebblebed::Http.get(url, {:text => text})
      result = JSON.parse(response.body)
      result['tokens'].count.should eq text.split(' ').count
      result['tokens'][0]['token'].should eq text[0]
    end
  end

  context "posts to river" do

    include Rack::Test::Methods

    def app
      TestSherlockV1
    end


    subject {
      Sherlock::UpdateListener.new({:name => 'highway_to_hell'})
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
          :document => {:app => "hot"},
          :paths => ["hell.tools.pitchfork"]
        }
      }
    }

    after(:each) do
      Sherlock::Elasticsearch.delete_index(realm)
      river.queue(:name => 'highway_to_hell').purge
      river.queue(:name => 'sherlock.index').purge
      river.queue(:name => 'river.index').purge
    end


    it "finds a created post with query" do
      river.publish(post)
      subject.start
      sleep 2

      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['total'].should eq 1
      result['pagination'].should_not eq nil
      result['hits'].first['hit']['uid'].should eq uid
      result['hits'].first['hit']['paths'].count.should eq 1
    end

    it "finds something for each entry in paths" do
      post = {
        :event => 'create',
        :uid => "associate:#{realm}.org$500",
        :attributes => {
          :first_name => "Frank",
          :last_name => "Larsen",
          :paths => ["#{realm}.org.oslo.sagene", "#{realm}.org.bergen.ulriken"]
        }
      }
      river.publish(post)
      subject.start
      sleep 1.4

      get "/search/#{realm}/associate:#{realm}.org.*"
      result = JSON.parse(last_response.body)
      result['total'].should eq 2
      result['hits'][0]['hit']['uid'].should eq "associate:#{realm}.org.oslo.sagene$500"
      result['hits'][1]['hit']['uid'].should eq "associate:#{realm}.org.bergen.ulriken$500"
    end

    it "udpates an existing post" do
      river.publish(post)
      subject.start
      sleep 1.4
      update_post = {
        :event => 'update',
        :uid => uid,
        :attributes => {:uid => uid, "document" => {:app => "lukewarm"}, :paths => ["hell.tools.pitchfork"]}
      }
      river.publish(update_post)
      sleep 1.4

      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['total'].should eq 0

      get "/search/#{realm}", :q => "lukewarm"
      result = JSON.parse(last_response.body)
      result['total'].should eq 1
      result['hits'].first['hit']['uid'].should eq uid
    end

    it "removes index for deleted post" do
      river.publish(post)
      subject.start
      sleep 1.4
      river.publish(post.merge(:event => 'delete'))
      sleep 1.4

      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['total'].should eq 0
    end

    it "does not find the post using non-matching query" do
      river.publish(post)
      subject.start
      sleep 1.4

      get "/search/#{realm}", :q => "lukewarm"
      result = JSON.parse(last_response.body)
      result['total'].should eq 0
    end

  end


end
