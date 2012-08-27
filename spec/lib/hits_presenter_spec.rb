require 'sherlock/hits_presenter'
require 'deepstruct'

describe Sherlock::HitsPresenter do

  subject {
    Sherlock::HitsPresenter.new({"took"=>3, "timed_out"=>false, "_shards"=>{"total"=>5, "successful"=>5, "failed"=>0}, "hits"=>{"total"=>2, "max_score"=>0.10848885, "hits"=>[{"_index"=>"test_hell", "_type"=>"post.card", "_id"=>"post.card:hell.pitchfork$1", "_score"=>0.10848885, "_source"=>{"document"=>{"app"=>"hot"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}, {"_index"=>"test_hell", "_type"=>"post.card", "_id"=>"post.card:hell.pitchfork$2", "_score"=>0.09492774, "_source"=>{"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$2"}}]}})
  }

  it "has correct hits" do
    expected = [{"document"=>{"app"=>"hot"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}, {"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$2"}]
    subject.hits.map(&:to_hash).should eq expected
  end

  it "delivers metadata"

end