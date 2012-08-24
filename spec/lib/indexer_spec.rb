require 'spec_helper'
#require_relative '../../lib/sherlock/indexer'


describe Sherlock::Indexer do

  subject {
    Sherlock::Indexer.new
  }

  let(:payload) {
    { 'event' => 'create',
      'uid' => 'post.card:hell.pitchfork$1',
      'attributes' => {'document' => {'app' => 'hot'}}
    }
  }

  it "builds an index record from payload" do    
    expected_record = {'document' => {'app' => 'hot'}, 'realm' => 'hell', 'uid' => 'post.card:hell.pitchfork$1'}
    subject.build_index_record(payload).should eq expected_record
  end

end