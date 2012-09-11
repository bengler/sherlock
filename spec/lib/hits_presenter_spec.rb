require 'sherlock/hits_presenter'
require 'deepstruct'
require 'spec_helper'

describe Sherlock::HitsPresenter do

  let(:total) { 2 }

  let(:search_result) {
    {
      "took"=>3,
      "timed_out"=>false,
      "_shards"=> {
        "total"=>5,
        "successful"=>5,
        "failed"=>0
      },
      "hits" => {
        "total"=>total,
        "max_score"=>0.10848885,
        "hits" => [
          { "_index"=>"test_hell",
            "_type"=>"post.card",
            "_id"=>"post.card:hell.pitchfork$1",
            "_score"=>0.10848885,
            "_source"=>{"document.app"=>"hot", "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1", "pristine"=>{"document"=>{"app"=>"hot"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}
          },
          {
            "_index"=>"test_hell",
            "_type"=>"post.card",
            "_id"=>"post.card:hell.pitchfork$2",
            "_score"=>0.09492774,
            "_source"=>{"document.app"=>"hot stuff", "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$2", "pristine"=>{"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}
          }
        ]
      }
    }
  }

  let(:pagination_options) {
    {:limit => 10, :offset => 0}
  }

  subject {
    Sherlock::HitsPresenter.new(search_result, pagination_options)
  }

  it "has correct hits" do
    expected = [{"document"=>{"app"=>"hot"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}, {"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}]
    subject.hits.map(&:to_hash).should eq expected
  end


  context "pagination" do

    let(:pagination) {
      subject.pagination
    }

    context "total is less than limit" do
      it { pagination.limit.should eq 10 }
      it { pagination.offset.should eq 0 }
      it { pagination.last_page.should eq true }
    end

    context "total equal to limit" do
      let(:pagination_options) {
        {:limit => 2, :offset => 0}
      }
      it { pagination.limit.should eq 2 }
      it { pagination.offset.should eq 0 }
      it { pagination.last_page.should eq true }
    end

    context "first page of total greater than limit" do
      let(:pagination_options) {
        {:limit => 2, :offset => 0}
      }
      let(:total) { 5 }
      it { pagination.limit.should eq 2 }
      it { pagination.offset.should eq 0 }
      it { pagination.last_page.should eq false }
    end

    context "last page of total greater than limit" do
      let(:pagination_options) {
        {:limit => 2, :offset => 4}
      }
      let(:total) { 6 }
      it { pagination.limit.should eq 2 }
      it { pagination.offset.should eq 4 }
      it { pagination.last_page.should eq true }
    end

    context "last page of total greater than limit (lots of results)" do
      let(:pagination_options) {
        {:limit => 10, :offset => 30}
      }
      let(:total) { 37 }
      it { pagination.last_page.should eq true }
    end


  end

  it "delivers metadata"

end