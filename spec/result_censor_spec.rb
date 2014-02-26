require 'sherlock/result_censor'

describe Sherlock::ResultCensor do

  let(:search_result) {
    {
      "took"=>3,
      "timed_out"=>false,
      "_shards"=> {
        "total"=>3,
        "successful"=>5,
        "failed"=>0
      },
      "hits" => {
        "total"=> 3,
        "max_score"=>0.10848885,
        "hits" => [
          { "_index"=>"test_hell",
            "_type"=>"post.card",
            "_id"=>"post.card:hell.pitchfork$1",
            "_score"=>0.10848885,
            "_source"=>{"document.app"=>"hot", "created_by" => 777, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1", "pristine"=>{"document"=>{"app"=>"hot"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}
          },
          {
            "_index"=>"test_hell",
            "_type"=>"post.card",
            "_id"=>"post.card:hell.pitchfork$2",
            "_score"=>0.09492774,
            "_source"=>{"document.app"=>"hot stuff", "created_by" => 777, "sensitive" => nil ,"realm"=>"hell", "uid"=>"post.card:hell.pitchfork$2", "pristine"=>{"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}
          },
          {
            "_index"=>"test_hell",
            "_type"=>"post.card",
            "_id"=>"post.card:hell.pitchfork$3",
            "_score"=>0.09492774,
            "_source"=>{"document.app"=>"hot stuff", "created_by" => 777, "sensitive" => "yup", "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$2", "pristine"=>{"document"=>{"app"=>"hot stuff"}, "realm"=>"hell", "uid"=>"post.card:hell.pitchfork$1"}}
          }

        ]
      }
    }
  }

  subject {
    Sherlock::ResultCensor
  }

  it "conceals the sensitive field for John Smith" do
    censored_result = subject.consider(search_result, false, 111)
    censored_result['hits']['hits'].map do |hit|
      hit['sensitive'].should eq nil
    end
  end

  it "discloses the sensitive field to owner" do
    censored_result = subject.consider(search_result, false, 777)
    censored_result['hits']['hits'][0]['_source']['sensitive'] == nil
    censored_result['hits']['hits'][1]['_source']['sensitive'] == nil
    censored_result['hits']['hits'][2]['_source']['sensitive'] == "yup"
  end

  it "discloses the sensitive field to god herself" do
    censored_result = subject.consider(search_result, true, nil)
    censored_result['hits']['hits'][0]['_source']['sensitive'] == nil
    censored_result['hits']['hits'][1]['_source']['sensitive'] == nil
    censored_result['hits']['hits'][2]['_source']['sensitive'] == "yup"
  end

end