
require 'pebblebed'
require 'sherlock'
require 'search'
ENV['RACK_ENV'] ||= 'test'

# post directly to river
  # something that matches
  # something that does not match
    # is not in es
# listen to river
# get all create, update, delete posts
# process these
  # create: exists in elasticsearch
  # delete: not in es
  # update: was changed in es

Thread.abort_on_exception = true

describe Sherlock do

  indexer_options = {:name => 'a_purdy_name', :path => 'hell.pitchfork|realm.stuff', :klass => 'post.card'}

  subject {
    Sherlock.new
  }

  before(:each) do
    Sherlock.environment = 'test'
    Sherlock.config
  end

  it "creates!" do
    river = Pebblebed::River.new
    river.publish(:event => 'create', :uid => 'post.card:hell.pitchfork$1', :attributes => {"document" => {:app => "ok"}})
    subject.run(indexer_options)
    sleep 1.2
    result = Search.perform_query("hell", "ok")
    result['hits']['total'].should eq 1
    result['hits']['hits'].first['_id'].should eq "post.card:hell.pitchfork$1"
  end

end
