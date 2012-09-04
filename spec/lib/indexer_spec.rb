require 'spec_helper'

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
    expected_record =  {"document.app"=>"hot", "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}
    subject.build_index_record(payload).should eq expected_record
  end

end
