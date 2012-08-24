require 'spec_helper'

describe Sherlock do

  it "configures nicely" do
    Sherlock.config.class.should eq Sherlock::Config
    Sherlock.config.services['grove'].should eq('session' => 'god', 'host' => 'grove.dev')
    Sherlock.config.services['elasticsearch'].should eq('host' => 'localhost:9200')
    Sherlock.config.environment.should eq 'test'
    Sherlock.indexer.should_not eq nil
  end

  it "gets an indexer" do
    Sherlock.indexer.should_not eq nil
  end

  it "triggers the indexer" do
    Sherlock.indexer.should_receive(:start)
    Sherlock.start_indexer
  end

end
