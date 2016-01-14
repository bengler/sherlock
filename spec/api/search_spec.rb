# encoding: utf-8
require 'spec_helper'
require 'api/v1'
require 'rack/test'
require 'active_support/all'
require 'uri'

class TestSherlockV1 < SherlockV1; end


describe 'API v1 search' do

  include Rack::Test::Methods
  include Pebblebed::RSpecHelper


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

  let(:yet_another_record) {
    uid = 'post.card:hell.flames.pitchfork$4'
    Sherlock::Parsers::Generic.new(uid, {'document' => "i'm tuffer than the rest", 'uid' => uid, :restricted => false}).to_hash
  }

  let(:nested_array_record) {
    uid = 'post.card:hell.flames.devil$5'
    data = {
      'uid' => uid,
      'document' => {
        'references' => [
          {
            'type' => 'reference',
            'to' => 'project',
            'id' => 10,
            'code' => 'onezero'
          },
          {
            'type' => 'reference',
            'to' => 'project',
            'id' => 11,
            'code' => 'oneone'
          }
        ]
      },
      :restricted => false
    }
    Sherlock::Parsers::Generic.new(uid, data).to_hash
  }

  let(:another_nested_array_record) {
    uid = 'post.card:hell.flames.devil$6'
    data = {
      'uid' => uid,
      'document' => {
        'references' => [
          {
            'type' => 'reference',
            'to' => 'project',
            'id' => 12,
            'code' => 'onetwo'
          },
          {
            'type' => 'reference',
            'to' => 'project',
            'id' => 13,
            'code' => 'onethree'
          }
        ]
      },
      :restricted => false
    }
    Sherlock::Parsers::Generic.new(uid, data).to_hash
  }


  after(:each) do
    Sherlock::Elasticsearch.delete_index(realm)
  end


  describe "GET /search/:realm/?:uid?" do

    it 'has correct content-type headers' do
      get "/search/#{realm}"
      last_response['Content-Type'].should eq 'application/json;charset=utf-8'
    end

    it 'finds existing record' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 2.0
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["hot", "hot stuff"]
      result['hits'].first['hit']['uid'].should eq record['uid']
    end

    it 'finds existing records by oid' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 2.0
      oids = [record, another_record].map {|r| r['uid'].split('$').last}

      endpoint = "/search/#{realm}/*:hell.*$#{oids.join('|')}"
      endpoint = URI.escape endpoint

      get endpoint
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['uid'].split('$').last
      end.should eq oids
      result['hits'].first['hit']['uid'].should eq record['uid']
      result['pagination']['limit'].should eq 2
    end

    it 'fails silently if an oid is missing' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 2.0
      oids = [record, another_record].map {|r| r['uid'].split('$').last}

      endpoint = "/search/#{realm}/*:hell.*$#{oids.join('||')}"
      endpoint = URI.escape endpoint

      get endpoint
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['uid'].split('$').last
      end.should eq oids
      result['hits'].first['hit']['uid'].should eq record['uid']
      result['pagination']['limit'].should eq 2
    end

    it 'raises an error on query at non-existing index' do
      get "/search/#{realm}", :q => "hot"
      result = JSON.parse(last_response.body)
      result['error'].should eq 'index_missing'
    end

    it "honors limit and offset" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      sleep 2.0
      get "/search/#{realm}", :q => "hot", :limit => 1, :offset => 1
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ['hot stuff']
    end

    it "requires limit and offset to be parsable as int" do
      Sherlock::Elasticsearch.index record
      sleep 2.0
      get "/search/#{realm}", :q => "hot", :limit => 'a'
      last_response.status.should eq 400
    end

    it "finds stuff with wildcard" do
      Sherlock::Elasticsearch.index yet_another_record
      sleep 2.0
      get "/search/#{realm}", :q => "*uffe*"
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["i'm tuffer than the rest"]
    end


    context "deprecated ranged query" do

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
        sleep 2.0
        get "/search/#{realm}", {:range => {:attribute => 'happens_on', :to => Date.today.to_s}}
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq ['past']
      end
    end

    context "ranged query" do

      context "date comparison" do

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
          sleep 2.0
          get "/search/#{realm}", {:max => {'happens_on' => Date.today.to_s}}
          result = JSON.parse(last_response.body)

          result['hits'].map do |hit|
            hit['hit']['document']
          end.should eq ['past']
        end

      end


      context "time comparison" do

        let(:close_future_record) {
          uid = 'post.card:hell.flames.devil$1'
          Sherlock::Parsers::Generic.new(uid, {'start_at' => (Time.now()+2.days).iso8601(3), 'document' => 'close future', 'uid' => uid, :restricted => false}).to_hash
        }
        let(:far_future_record) {
          uid = 'post.card:hell.flames.pitchfork$2'
          Sherlock::Parsers::Generic.new(uid, {'start_at' => (Time.now()+30.days).iso8601(3), 'document' => 'far future', 'uid' => uid, :restricted => false}).to_hash
        }

        it "works" do
          Sherlock::Elasticsearch.index close_future_record
          Sherlock::Elasticsearch.index far_future_record
          sleep 2.0

          get "/search/#{realm}", {:min => {'start_at' => (Time.now()+3.days).iso8601(3)}}
          result = JSON.parse(last_response.body)

          result['hits'].map do |hit|
            hit['hit']['document']
          end.should eq ['far future']
        end

      end

    end


    context "ranged query with multiple ranges" do

      let(:record1) {
        uid = 'post.card:hell.flames.devil$1'
        Sherlock::Parsers::Generic.new(uid,
          {
            'happens_on' => (Date.today-5).to_s,
            'created_at' => (Date.today-7).to_s,
            'document' => 'one',
            'uid' => uid,
            :restricted => false
          }).to_hash
      }
      let(:record2) {
        uid = 'post.card:hell.flames.pitchfork$2'
        Sherlock::Parsers::Generic.new(uid,
          {
            'happens_on' => (Date.today+0).to_s,
            'created_at' => (Date.today+0).to_s,
            'document' => 'two',
            'uid' => uid,
            :restricted => false
          }).to_hash
      }
      let(:record3) {
        uid = 'post.card:hell.flames.pitchfork$3'
        Sherlock::Parsers::Generic.new(uid,
          {
            'happens_on' => (Date.today+10).to_s,
            'created_at' => (Date.today+0).to_s,
            'document' => 'three',
            'uid' => uid,
            :restricted => false
          }).to_hash
      }

      it "works" do
        Sherlock::Elasticsearch.index record1
        Sherlock::Elasticsearch.index record2
        Sherlock::Elasticsearch.index record3
        sleep 2.0
        options = {
          :max => {
            :happens_on => (Date.today+1).to_s,
            :created_at => (Date.today+1).to_s
          },
          :min => {
            :happens_on => (Date.today-10).to_s,
            :created_at => (Date.today-1).to_s
          }
        }
        get "/search/#{realm}", options
        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['document']
        end.should eq ['two']
      end
    end


    context 'field must match' do
      let(:record) {
        uid = 'post.card:hell.flames.devil$1'
        Sherlock::Parsers::Generic.new(uid, {'document' => {'id' => 123, 'foo' => 'Foo BØr'}, 'uid' => uid}).to_hash
      }
      let(:another_record) {
        uid = 'post.card:hell.flames.pitchfork$2'
        Sherlock::Parsers::Generic.new(uid, {'document' => {'id' => 234, 'foo' => 'foo bør'}, 'id' => 123, 'uid' => uid}).to_hash
      }
      let(:third_record) {
        uid = 'post.card:hell.flames.pitchfork$2'
        Sherlock::Parsers::Generic.new(uid, {'document' => {'id' => 345, 'foo' => 'banana'}, 'uid' => uid}).to_hash
      }

      it "is utf-8 case insensitive" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        Sherlock::Elasticsearch.index third_record
        sleep 2.0
        get "/search/#{realm}/post.card:hell.*", {:"field[document.foo]" => 'Foo Bør'}
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].map{|h| h['hit']['uid']}.should == ["post.card:hell.flames.devil$1", "post.card:hell.flames.pitchfork$2"]
      end

      it "can search for id-field if prefixed with document" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        Sherlock::Elasticsearch.index third_record
        sleep 2.0
        get "/search/#{realm}/post.card:hell.*", {:"fields[document.id]" => 123}
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].first['hit']['uid'].should eq 'post.card:hell.flames.devil$1'
        get "/search/#{realm}/post.card:hell.*", {:"fields[id]" => 123}
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 0
      end

      it "can not search for id-field if 'id' is ambiguous in the data and not prefixed with document in the query" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        Sherlock::Elasticsearch.index third_record
        sleep 2.0
        get "/search/#{realm}/post.card:hell.*", {:"fields[id]" => 123}
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 0
      end

      it "finds records by contents in array" do
        Sherlock::Elasticsearch.index nested_array_record
        Sherlock::Elasticsearch.index another_nested_array_record
        sleep 1.5

        query_params = {
          :"fields[document.references.id]" => '10'
        }
        get "/search/#{realm}/post.card:hell.*", query_params
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        expected = {"type"=>"reference", "to"=>"project", "id"=>10, "code"=>"onezero"}
        result['hits'].first['hit']['document']['references'].first.should eq expected
      end

    end

    context 'field must exist' do
      let(:record) {
        uid = 'post.card:hell.flames.devil$1'
        Sherlock::Parsers::Generic.new(uid, {'document' => 'bling', 'uid' => uid}).to_hash
      }
      let(:another_record) {
        uid = 'post.card:hell.flames.pitchfork$2'
        Sherlock::Parsers::Generic.new(uid, {'document' => nil, 'uid' => uid}).to_hash
      }

      it "works" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index another_record
        sleep 2.0

        get "/search/#{realm}/post.card:hell.*", {:fields => {:document => '!null'}}
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].first['hit']['uid'].should eq 'post.card:hell.flames.devil$1'
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

      let(:third_record) {
        uid = 'post.card:hell.flames.bbq$3'
        Sherlock::Parsers::Generic.new(uid, {:restricted => false, 'document' => {'item' => 'second bbq', 'happens_on' => '2001-12-25'}, 'uid' => uid}).to_hash
      }

      it "sorts by date in correct order" do
        Sherlock::Elasticsearch.index first_record
        sleep 2.0
        Sherlock::Elasticsearch.index second_record
        sleep 2.0
        Sherlock::Elasticsearch.index third_record
        sleep 2.0
        get "/search/#{realm}", :q => "bbq", :sort_by => "document.happens_on", :order => 'asc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 3
        result['hits'].first['hit']['document']['item'].should eq 'first bbq'

        get "/search/#{realm}", :q => "bbq", :sort_by => "document.happens_on", :order => 'desc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 3
        result['hits'].first['hit']['document']['item'].should eq 'second bbq'

        get "/search/#{realm}", :q => "bbq", :sort_by => "document.item, document.happens_on", :order => 'desc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 3
        result['hits'].first['hit']['document']['item'].should eq 'second bbq'
        result['hits'].first['hit']['document']['happens_on'].should eq '2001-12-25'

        get "/search/#{realm}", :q => "bbq", :sort_by => "document.item, document.happens_on", :order => 'desc,asc'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 3
        result['hits'].first['hit']['document']['item'].should eq 'second bbq'
        result['hits'].first['hit']['document']['happens_on'].should eq '2001-12-24'

      end

    end
  end

  describe '/search/post.card:hell.*' do
    it "works" do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 2.0

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
      sleep 2.0

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
      Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'deleted' => false, 'published' => true}).to_hash
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
        sleep 2.0
        get "/search/#{realm}", :q => 'secret', :deleted => 'include'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 3
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
        sleep 2.0
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

          sleep 2.0
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

          sleep 2.0
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

          sleep 2.0
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
        sleep 2.0

        get "/search/#{realm}/#{restricted_uid}"

        result = JSON.parse(last_response.body)
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([restricted_uid])
      end

      it "it finds the record on a term search" do
        Sherlock::Elasticsearch.index restricted_record
        sleep 2.0

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
        sleep 2.0
        get "/search/heaven", :q => 'secret'

        result = JSON.parse(last_response.body)
        result['hits'].should eq []
      end

    end

    context "when John Q. Public" do
      it "is not found" do
        Sherlock::Elasticsearch.index restricted_record
        sleep 2.0

        get "/search/#{realm}", :q => 'secret'

        result = JSON.parse(last_response.body)
        result['hits'].should eq []
      end
    end
  end

  describe "sensitive field" do

    before :each do
      Sherlock::Access.stub(:accessible_paths).and_return ['hell.tools']
    end

    let(:uid) {
      'post.card:hell.tools.devil$1'
    }

    let(:sensitive_record) {
      Sherlock::Parsers::Generic.new(uid, {'created_by' => 1, 'document' => {'title' => 'hot'}, 'sensitive' => {'email' => 'jazzydevil88@hotmail.com'}, 'uid' => uid, :restricted => false}).to_hash
    }

    context 'is disclosed to owner' do

      before(:each) { user!(:id => 1) }

      it 'works' do
        Sherlock::Elasticsearch.index sensitive_record
        sleep 2.0
        get "/search/#{realm}", :q => "hot"
        result = JSON.parse(last_response.body)
        hit = result['hits'].first['hit']
        hit['uid'].should eq uid
        hit['sensitive']['email'].should eq 'jazzydevil88@hotmail.com'
      end

    end

    context 'is concealed from non-owners' do

      before(:each) { user!(:id => 2) }

      it 'works' do
        Sherlock::Elasticsearch.index sensitive_record
        sleep 2.0
        get "/search/#{realm}", :q => "hot"
        result = JSON.parse(last_response.body)
        hit = result['hits'].first['hit']
        hit['uid'].should eq uid
        hit['sensitive'].should eq nil
      end
    end

    context 'is concealed from non-owners' do

      before(:each) { god! }

      it 'works' do
        Sherlock::Elasticsearch.index sensitive_record
        sleep 2.0
        get "/search/#{realm}", :q => "hot"
        result = JSON.parse(last_response.body)
        hit = result['hits'].first['hit']
        hit['uid'].should eq uid
        hit['sensitive']['email'].should eq 'jazzydevil88@hotmail.com'
      end
    end

  end


  describe 'find fresh stuff' do

    context 'reindexing a field' do

      let(:uid) {
        'post.card:hell.pitchfork$99'
      }
      let(:createPayload) {
        { 'event' => 'create',
          'uid' => uid,
          'attributes' => {
            'uid' => uid,
            'document' => {'app' => 'fridayisspandexday'},
            'protected' => {'price' => 'expensive'},
            'paths' => ['hell.pitchfork'],
            'id' => uid
          }
        }
      }
      let(:updatePayload) {
        { 'event' => 'update',
          'uid' => uid,
          'attributes' => {
            'uid' => uid,
            'document' => {'app' => 'fridayisspandexday'},
            'protected' => {'price' => 'expensive', 'status' => 'all good'},
            'paths' => ['hell.pitchfork'],
            'id' => uid
          }
        }
      }

      it 'works' do
        expectedCreate = {"uid"=>uid, "document.app"=>"fridayisspandexday", "protected.price"=>"expensive", "paths"=>["hell.pitchfork"], "id"=>uid, "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"1", "realm"=>"hell", "pristine"=>{"uid"=>uid, "document"=>{"app"=>"fridayisspandexday"}, "protected"=>{"price"=>"expensive"}, "paths"=>["hell.pitchfork"], "id"=>uid}, "restricted"=>false}
        expectedUpdate = {"uid"=>uid, "document.app"=>"fridayisspandexday", "protected.price"=>"expensive", "protected.status"=>"all good", "paths"=>["hell.pitchfork"], "id"=>uid, "klass_0_"=>"post", "klass_1_"=>"card", "label_0_"=>"hell", "label_1_"=>"pitchfork", "oid_"=>"99", "realm"=>"hell", "pristine"=>{"uid"=>uid, "document"=>{"app"=>"fridayisspandexday"}, "protected"=>{"price"=>"expensive", "status"=>"all good"}, "paths"=>["hell.pitchfork"], "id"=>uid}, "restricted"=>false}

        expected_calls = (TEST_RUNNING_ON_SEMAPHORE == true) ? 20 : 21
        # 21 becase action.auto_create_index: false
        Sherlock::Elasticsearch.should_receive(:index).exactly(expected_calls).and_call_original

        10.times do
          Sherlock::UpdateListener.new.consider createPayload
          Sherlock::UpdateListener.new.consider updatePayload
        end
        sleep 2

        get '/search/hell/post.card:*', :q => '99'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].first['hit']['protected']['status'].should eq 'all good'
      end

    end

  end


  describe "caching results" do

    let(:uid) {
      'post.card:hell.flames.blaff$555'
    }
    let(:original_content) {
      'stuff'
    }
    let(:updated_content) {
      'nuff stuff'
    }
    let(:record_hash) {
      {'document' => original_content, 'uid' => uid, :restricted => false}
    }

    before :each do
      Sherlock::Access.stub(:accessible_paths).and_return []

      rec = Sherlock::Parsers::Generic.new(uid, record_hash).to_hash
      Sherlock::Elasticsearch.index rec
      sleep 2.0

      guest!
      # do query as guest to prime the cache
      get '/search/hell/post.card:*', :q => 'stuff'

      # update the record
      record_hash['document'] = updated_content
      rec = Sherlock::Parsers::Generic.new(uid, record_hash).to_hash
      Sherlock::Elasticsearch.index rec
    end

    context "logged in user always gets updated stuff" do
      it "works" do
        sleep 2.0
        user!
        get '/search/hell/post.card:*', :q => 'stuff'
        result = JSON.parse(last_response.body)
        result['hits'].first['hit']['document'].should eq updated_content
      end
    end

    context "non-logged in user gets updated stuff if nocache flag is set" do
      it "works" do
        sleep 2.0
        guest!
        get '/search/hell/post.card:*', {:q => 'stuff', :nocache => true}
        result = JSON.parse(last_response.body)
        result['hits'].first['hit']['document'].should eq updated_content
      end
    end

    context "non-logged in user gets cached stuff" do
      it "works" do
        sleep 2.0
        guest!
        get '/search/hell/post.card:*', :q => 'stuff'
        result = JSON.parse(last_response.body)
        result['hits'].first['hit']['document'].should eq original_content
      end
    end

  end

  describe 'returns only specified fields' do

    it 'works' do
      uid = 'post.card:hell.flames.devil$1'
      record_hash = {'document' => 'hot', 'uid' => uid, :restricted => false}
      Sherlock::Parsers::Generic.new(uid, record_hash).to_hash
      Sherlock::Elasticsearch.index record
      sleep 1.5

      get "/search/#{realm}/#{uid}", :return_fields => 'restricted'
      result = JSON.parse(last_response.body)

      result['hits'].count.should eq 1
      result['hits'].first['hit']['uid'].should eq uid
      result['hits'].first['hit']['document'].should eq nil
      result['hits'].first['hit']['score'].should eq nil
      result['hits'].first['hit']['restricted'].should eq false
    end

  end

  describe "content marked as unpublished" do

    let(:uid) {'post.card:hell.tools.weird$1'}
    let(:unpublished_uid) {'post.card:hell.tools.weird$2'}

    let(:record) {
      Sherlock::Parsers::Generic.new(uid, {'document' => 'secret', 'uid' => uid, 'published' => true, 'restricted' => false}).to_hash
    }
    let(:unpublished_record) {
      Sherlock::Parsers::Generic.new(unpublished_uid, {'document' => 'secret', 'uid' => unpublished_uid, 'published' => false, 'restricted' => false}).to_hash
    }

    context "when somewhat entrusted" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return ['hell.tools']
      end

      it "finds unpublished stuff when requested" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index unpublished_record
        sleep 2.0
        get "/search/#{realm}", :q => 'secret', :unpublished => 'include'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 2
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([record['uid'], unpublished_record['uid']])
      end

      it "finds only unpublished stuff when requested" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index unpublished_record
        sleep 2.0
        get "/search/#{realm}", :q => 'secret', :unpublished => 'only'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([unpublished_record['uid']])
      end

      it "does not find unpublished stuff unless explicitly told to do so" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index unpublished_record
        sleep 2.0
        get "/search/#{realm}", :q => 'secret'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([record['uid']])
      end

    end


    context "not trusted" do

      before :each do
        Sherlock::Access.stub(:accessible_paths).and_return []
      end

      it "never finds unpublished stuff when requested" do
        Sherlock::Elasticsearch.index record
        Sherlock::Elasticsearch.index unpublished_record
        sleep 2.0

        get "/search/#{realm}", :q => 'secret'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([record['uid']])

        get "/search/#{realm}", :q => 'secret', :unpublished => 'include'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 1
        result['hits'].map do |hit|
          hit['hit']['uid']
        end.sort.should eq([record['uid']])

        get "/search/#{realm}", :q => 'secret', :unpublished => 'only'
        result = JSON.parse(last_response.body)
        result['hits'].count.should eq 0
      end

    end

  end

  describe "POST /search/:realm/?:uid?" do

    it 'finds existing record' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      sleep 2.0
      post "/search/#{realm}", {:q => 'hot'}
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['document']
      end.should eq ["hot", "hot stuff"]
      result['hits'].first['hit']['uid'].should eq record['uid']
    end

    it 'finds records by uid in request body' do
      Sherlock::Elasticsearch.index record
      Sherlock::Elasticsearch.index another_record
      Sherlock::Elasticsearch.index excluded_record
      Sherlock::Elasticsearch.index yet_another_record
      sleep 2.0
      post "/search/#{realm}", {:uid => 'post.card:hell.*$1|4'}
      result = JSON.parse(last_response.body)
      result['hits'].map do |hit|
        hit['hit']['uid']
      end.should eq [record['uid'], yet_another_record['uid']]
    end

  end

end
