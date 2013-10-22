require 'pebblebed'
require 'sherlock/query'
require 'approvals/rspec'
require 'spec_helper'

describe Sherlock::Query do

  specify "limit and offset" do
    Sherlock::Query.new({}).limit.should eq 10
    Sherlock::Query.new({}).offset.should eq 0
  end

  specify "simple query" do
    verify :format => :json do
      Sherlock::Query.new(:q => 'hot').to_json
    end
  end

  specify "simple query with wildcard uid" do
    verify :format => :json do
      Sherlock::Query.new({:q => 'torrid', :uid => '*:*'}).to_json
    end
  end

  specify "simple query with pagination" do
    verify :format => :json do
      Sherlock::Query.new({:q => 'blazing', :limit => 5, :offset => 10}).to_json
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
      Sherlock::Query.new({:q => 'burning', :uid => 'post.card:hell.flames.*'}).to_json
    end
  end

  specify "fully qualified uid path" do
    verify :format => :json do
      Sherlock::Query.new({:q => 'scalding', :uid => 'post.card:hell.flames'}).to_json
    end
  end

  specify "wildcard klass with wildcard path" do
    verify :format => :json do
      Sherlock::Query.new({:q => 'blistering', :uid => '*:hell.flames.*'}).to_json
    end
  end

  specify "fully qualified uid with search term and pagination" do
    verify :format => :json do
      params = {:q => 'fiery', :uid => 'post.card:hell.flames', :limit => 5, :offset => 10}
      Sherlock::Query.new(params).to_json
    end
  end

  specify "wildcard uid with search term and pagination" do
    verify :format => :json do
      params = {:q => 'incandescent', :uid => 'post.card:hell.flames.*', :limit => 5, :offset => 10}
      Sherlock::Query.new(params).to_json
    end
  end

  specify "full uid with oid" do
    verify :format => :json do
      Sherlock::Query.new({:q => 'scorching', :uid => 'post.card:hell.flames$123'}).to_json
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

  describe "range" do
    it "will only query within the mentioned range" do
      verify :format => :json do
        range = {'attribute' => 'membership_expires_on', 'to' => '2012-11-01', 'from' => '2012-11-03'}
        Sherlock::Query.new({:q => 'scorching', :range => range}).to_json
      end
    end
  end

  describe "field" do
    it "specifies the value of various fields" do
      verify :format => :json do
        fields = {}
        fields['membership_expires_on'] = '2012-12-24'
        fields['status'] = 'null'
        fields['provider'] = 'origo|facebook'
        Sherlock::Query.new({:q => 'scorching', :fields => fields}).to_json
      end
    end

  end

  describe "tags" do
    it "support simple tag queries" do
      Sherlock::Query.new({:q => 'music', :tags => "rock"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"term\":{\"tags_vector\":\"rock\"}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "!rock"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"not\":{\"term\":{\"tags_vector\":\"rock\"}}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "!rock & pop"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"not\":{\"term\":{\"tags_vector\":\"rock\"}}},{\"term\":{\"tags_vector\":\"pop\"}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "!rock & (pop|techno)"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"not\":{\"term\":{\"tags_vector\":\"rock\"}}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}],\"or\":[{\"term\":{\"tags_vector\":\"pop\"}},{\"term\":{\"tags_vector\":\"techno\"}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "rock & pop"}).to_json.should ==  "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"term\":{\"tags_vector\":\"rock\"}},{\"term\":{\"tags_vector\":\"pop\"}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "rock & !pop"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"term\":{\"tags_vector\":\"rock\"}},{\"not\":{\"term\":{\"tags_vector\":\"pop\"}}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
      Sherlock::Query.new({:q => 'music', :tags => "rock,pop,blues"}).to_json.should == "{\"from\":0,\"size\":10,\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"music\",\"default_operator\":\"AND\"}}]}},\"filter\":{\"and\":[{\"term\":{\"tags_vector\":\"rock\"}},{\"term\":{\"tags_vector\":\"pop\"}},{\"term\":{\"tags_vector\":\"blues\"}},{\"and\":[{\"term\":{\"restricted\":false}},{\"not\":{\"term\":{\"deleted\":true}}}]}]}}"
    end

  end

  describe "access" do

    it "grants access to a specifc path" do
      accessible_paths = ['dna.org.vaffel']
      verify :format => :json do
        Sherlock::Query.new({:q => 'scorching'}, accessible_paths).to_json
      end
    end

    it "grants access to specifc sub-paths" do
      accessible_paths = ['dna.org.vaffel', 'dna.org.pannekake']
      verify :format => :json do
        Sherlock::Query.new({:q => 'asdf'}, accessible_paths).to_json
      end
    end

    it "grants access to a specifc path with overlapping uid" do
      accessible_paths = ['dna.org.vaffel']
      verify :format => :json do
        Sherlock::Query.new({:q => 'scorching', :uid => '*:dna.org.*'}, accessible_paths).to_json
      end
    end

    it "denies access to a specifc path with non-overlapping uid" do
      accessible_paths = ['dna.org.vaffel']
      verify :format => :json do
        Sherlock::Query.new({:q => 'scorching', :uid => '*:dna.gro.*'}, accessible_paths).to_json
      end
    end


    context "deleted content" do

      xit "grants access to a specifc path" do
        accessible_paths = ['dna.org.vaffel']
        verify :format => :json do
          Sherlock::Query.new({:q => 'scorching'}, accessible_paths).to_json
        end
      end
    end

  end

end
