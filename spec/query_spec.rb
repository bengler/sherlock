require 'pebblebed'
require 'sherlock/query'
require 'approvals/rspec'
require 'spec_helper'

describe Sherlock::Query do
  its(:limit) { should eq(10) }
  its(:offset) { should eq(0) }

  specify "simple query" do
    verify :format => :json do
      Sherlock::Query.new('q' => 'hot').to_json
    end
  end

  specify "simple query with wildcard uid" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'torrid', :uid => '*:*').to_json
    end
  end

  specify "simple query with pagination" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'blazing', :limit => 5, :offset => 10).to_json
    end
  end

  specify "wildcard uid filter" do
    verify :format => :json do
      Sherlock::Query.new(:uid => 'post.card:hell.flames.*').to_json
    end
  end

  specify "fully qualified path in uid filter without search term" do
    verify :format => :json do
      Sherlock::Query.new(:uid => 'post.card:hell.flames').to_json
    end
  end

  specify "uid filter with search term" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'burning', :uid => 'post.card:hell.flames.*').to_json
    end
  end

  specify "fully qualified uid path" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'scalding', :uid => 'post.card:hell.flames').to_json
    end
  end

  specify "wildcard klass with wildcard path" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'blistering', :uid => '*:hell.flames.*').to_json
    end
  end

  specify "fully qualified uid with search term and pagination" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'fiery', :uid => 'post.card:hell.flames', :limit => 5, :offset => 10).to_json
    end
  end

  specify "wildcard uid with search term and pagination" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'incandescent', :uid => 'post.card:hell.flames.*', :limit => 5, :offset => 10).to_json
    end
  end

  specify "full uid with oid" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'scorching', :uid => 'post.card:hell.flames$123').to_json
    end
  end

  describe "normalizing input" do

    specify "sort order" do
      Sherlock::Query.normalize_sort_order('asc').should eq 'asc'
      Sherlock::Query.normalize_sort_order('ASC').should eq 'asc'
      Sherlock::Query.normalize_sort_order('desc').should eq 'desc'
      Sherlock::Query.normalize_sort_order('DESC').should eq 'desc'
      Sherlock::Query.normalize_sort_order('anything').should eq 'desc'
    end

  end

  describe "restricted content" do
    it "is exluded from query by default" do
      verify :format => :json do
        Sherlock::Query.new(:q => 'scorching').to_json
      end
    end

    it "is included if specified" do
      verify :format => :json do
        Sherlock::Query.new(:q => 'scorching', :show_restricted => true).to_json
      end
    end
  end

  describe "range" do
    it "will only query within the mentioned range" do
      verify :format => :json do
        range = {'attribute' => 'membership_expires_on', 'to' => '2012-11-01', 'from' => '2012-11-03'}
        Sherlock::Query.new(:q => 'scorching', :range => range).to_json
      end
    end
  end

  describe "field" do
    it "specifies a missing field" do
      verify :format => :json do
        field = {'name' => 'membership_expires_on', 'value' => 'null'}
        Sherlock::Query.new(:q => 'scorching', :field => field).to_json
      end
    end

    it "specifies the attribute of a field"

  end

end
