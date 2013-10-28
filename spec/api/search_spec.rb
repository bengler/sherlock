require "spec_helper"
require 'api/v1'
require 'rack/test'

class TestSherlockV1 < SherlockV1; end

describe 'API v1 search' do

  include Rack::Test::Methods

  def app
    TestSherlockV1
  end

  let(:realm) {
    'hell'
  }

  let(:record) {
    uid = 'post.card:hell.flames.devil$1'
    Sherlock::Parsers::Generic.new(uid, {'document' => 'hot', 'uid' => uid, :restricted => false}).to_hash
  }

  let(:another_record) {
    uid = 'post.card:hell.flames.pitchfork$2'
    Sherlock::Parsers::Generic.new(uid, {'document' => 'hot stuff', 'uid' => uid, :restricted => false}).to_hash
  }

  let(:excluded_record) {
    uid = 'post.card:hell.heck.weird$3'
    Sherlock::Parsers::Generic.new(uid, {'document' => 'warm', 'uid' => uid, :restricted => false}).to_hash
  }

  after(:each) do
    Sherlock::Elasticsearch.delete_index(realm)
  end


  describe "GET /search/:realm/?:uid?" do

    it 'finds existing record' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 1.5
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["hot", "hot stuff"]
      result['hits'].first['hit']['uid'].should eq record['uid']
    end

    it 'delivers empty result set for non-existing index' do
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].should eq []
    end

    it "honors limit and offset" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      sleep 1.5
      get "/search/#{realm}", :q => "hot", :limit => 1, :offset => 1
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ['hot stuff']
    end

    context "ranged query" do

      let(:record) {
        uid = 'post.card:hell.flames.devil$1'
        Sherlock::Parsers::Generic.new(uid, {'happens_on' => (Date.today-5).to_s, 'document' => 'past', 'uid' => uid, :restricted => false}).to_hash
      }
      let(:another_record) {
        uid = 'post.card:hell.flames.pitchfork$2'
        Sherlock::Parsers::Generic.new(uid, {'happens_on' => (Date.today+5).to_s, 'document' => 'future', 'uid' => uid, :restricted => false}).to_hash
      }

      it "works" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        sleep 1.5
        get "/search/#{realm}", {:range => {:attribute => 'happens_on', :to => Date.today.to_s}}
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq ['past']
      end
    end

    context "sorting results" do

      let(:first_record) {
        uid = 'post.card:hell.flames.bbq$1'
        Sherlock::Parsers::Generic.new(uid, {:restricted => false, 'document' => {'item' => 'first bbq', 'happens_on' => '2000-12-24'}, 'uid' => uid}).to_hash
      }

      let(:second_record) {
        uid = 'post.card:hell.flames.bbq$2'
        Sherlock::Parsers::Generic.new(uid, {:restricted => false, 'document' => {'item' => 'second bbq', 'happens_on' => '2001-12-24'}, 'uid' => uid}).to_hash
      }

      it "sorts by date in correct order" do
        Sherlock::Elasticsearch.index first_record
        sleep 1.5
        Sherlock::Elasticsearch.index second_record
        sleep 1.5
        get "/search/#{realm}", :q => "bbq", :sort_by => "document.happens_on", :order => 'asc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].first['hit']['document']['item'].should eq 'first bbq'

        get "/search/#{realm}", :q => "bbq", :sort_by => "document.happens_on", :order => 'desc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].first['hit']['document']['item'].should eq 'second bbq'
      end

    end
  end

  describe '/search/post.card:hell.*' do
    it "works" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 1.5

      get "/search/#{realm}/post.card:hell.flames.*", :q => "hot"

      result = JSON.parse(last_response.body)

      result['hits'].map do |hit|
        hit['hit']['uid']
      end.sort.should eq(["post.card:hell.flames.devil$1", "post.card:hell.flames.pitchfork$2"])
    end

  end

  describe '/search/realm/fulluid' do
    it "works" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      sleep 1.5

      get "/search/#{realm}/#{record['uid']}"

      result = JSON.parse(last_response.body)

      result['hits'].map do |hit|
        hit['hit']['uid']
      end.sort.should eq([record['uid']])
    end
  end

  describe "content marked as deleted" do

    let(:uid) {'post.card:hell.tools.weird$1'}
    let(:restricted_uid) {'post.card:hell.tools.weird$2'}
    let(:deleted_uid) {'post.card:hell.tools.weird$3'}
    let(:inaccessible_deleted_uid) {'post.card:hell.climate.weird$4'}

    let(:record) {
      Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'deleted' => false}).to_hash
    }
    let(:restricted_record) {
      Sherlock::Parsers::Generic.new(restricted_uid, {'document' => 'secret', 'uid' => restricted_uid, 'deleted' => false, 'restricted' => true}).to_hash
    }
    let(:deleted_record) {
      Sherlock::Parsers::Generic.new(deleted_uid, {'document' => 'secret', 'uid' => deleted_uid, 'deleted' => true}).to_hash
    }
    let(:inaccessible_deleted_record) {
      Sherlock::Parsers::Generic.new(inaccessible_deleted_uid, {'document' => 'secret', 'uid' => inaccessible_deleted_uid, 'deleted' => true}).to_hash
    }

    context "when somewhat entrusted" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return ['hell.tools']
      end

      it "finds what it should and not more" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index restricted_record
        Sherlock::Elasticsearch.index deleted_record
        Sherlock::Elasticsearch.index inaccessible_deleted_record
        sleep 1.5
        get "/search/#{realm}", :q => 'secret', :deleted => 'include'
        result = JSON.parse(last_response.body)
        #result['hits'].count.should eq 3
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([record['uid'], restricted_record['uid'], deleted_record['uid']])
      end

    end

    context "only deleted content" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return ['hell.tools']
      end

      let(:uid) {'post.card:hell.tools.weird$1'}
      let(:deleted_uid) {'post.card:hell.tools.weird$2'}
      let(:record) {
        Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'deleted' => false}).to_hash
      }
      let(:deleted_record) {
        Sherlock::Parsers::Generic.new(deleted_uid, {'document' => 'secret', 'uid' => deleted_uid, 'deleted' => true}).to_hash
      }

      it "finds what it should and not more" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index deleted_record
        sleep 1.5
        get "/search/#{realm}", :q => 'secret', :deleted => 'only'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].first['hit']['uid'].should eq deleted_record['uid']
      end

    end
  end


  describe "restricted content" do

    let(:restricted_uid) {'post.card:hell.heck.weird$1'}

    let(:restricted_record) {
      Sherlock::Parsers::Generic.new(restricted_uid, {'document' => 'secret', 'uid' => restricted_uid, 'restricted' => true}).to_hash
    }

    context "when somewhat entrusted" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return ['hell.heck', 'hell.tools']
      end

      let(:another_restricted_record) {
        uid = 'post.card:hell.tools.weird$2'
        Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'restricted' => true}).to_hash
      }

      let(:inaccessible_restricted_record) {
        uid = 'post.card:hell.yeah.weird$3'
        Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'restricted' => true}).to_hash
      }

      context "searching by path" do

        it "finds what it should and not more" do
          Sherlock::Elasticsearch.index restricted_record
          Sherlock::Elasticsearch.index another_restricted_record
          Sherlock::Elasticsearch.index inaccessible_restricted_record
          record['document'] = 'not secret'
          record['restricted'] = false
          Sherlock::Elasticsearch.index record

          sleep 1.5
          get "/search/#{realm}", :q => 'secret'
          result = JSON.parse(last_response.body)
          result['hits'].map do |hit|
            hit['hit']['uid']
          end.sort.should eq([record['uid'], restricted_record['uid'], another_restricted_record['uid']])
        end

      end

      context "searching by uid" do

        it "finds what it should and not more" do
          Sherlock::Elasticsearch.index restricted_record
          Sherlock::Elasticsearch.index another_restricted_record
          Sherlock::Elasticsearch.index inaccessible_restricted_record
          record['restricted'] = false
          Sherlock::Elasticsearch.index record

          sleep 1.5
          get "/search/#{realm}/post.card:hell.*"
          result = JSON.parse(last_response.body)
          result['hits'].map do |hit|
            hit['hit']['uid']
          end.sort.should eq([record['uid'], restricted_record['uid'], another_restricted_record['uid']])
        end

        it "finds what it should and not more and missing field does not cause query breakage" do
          Sherlock::Elasticsearch.index restricted_record
          Sherlock::Elasticsearch.index another_restricted_record
          Sherlock::Elasticsearch.index inaccessible_restricted_record
          record['restricted'] = false
          Sherlock::Elasticsearch.index record

          sleep 1.5
          get "/search/#{realm}/post.card:hell.*", 'fields[blipp]' => 'null'
          result = JSON.parse(last_response.body)
          result['hits'].map do |hit|
            hit['hit']['uid']
          end.sort.should eq([record['uid'], restricted_record['uid'], another_restricted_record['uid']])
        end

      end

    end


    context "when god" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return [realm]
      end

      it "finds the record on a uid search" do
        # denne testen feiler når query.rb:95 er med
        Sherlock::Elasticsearch.index restricted_record
        sleep 1.5

        get "/search/#{realm}/#{restricted_uid}"

        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([restricted_uid])
      end

      it "it finds the record on a term search" do
        Sherlock::Elasticsearch.index restricted_record
        sleep 1.5

        get "/search/#{realm}", :q => 'secret'

        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([restricted_uid])
      end

      it "doesnt find stuff in another realm" do
        restricted_uid = 'post.card:heaven.wish.you.were.here$1'
        restricted_record = Sherlock::Parsers::Generic.new(restricted_uid, {'document' => 'secret', 'uid' => restricted_uid, 'restricted' => true}).to_hash

        Sherlock::Elasticsearch.index restricted_record
        sleep 1.5
        get "/search/heaven", :q => 'secret'

        result = JSON.parse(last_response.body)
        result['hits'].should eq []
      end

    end

    context "when John Q. Public" do
      it "is not found" do
        Sherlock::Elasticsearch.index restricted_record
        sleep 1.5

        get "/search/#{realm}", :q => 'secret'

        result = JSON.parse(last_response.body)
        result['hits'].should eq []
      end
    end
  end

end
