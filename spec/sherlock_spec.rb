require 'sherlock'

describe Sherlock do

  subject { Sherlock.new }

  before(:each) do
    Sherlock.environment = 'test'
  end

  it "configures" do
    Sherlock.config['grove'].should eq('session' => 'god', 'host' => 'grove.dev')
    subject.indexer.should_not eq nil
  end

  it "gets an indexer" do
    subject.indexer.should_not eq nil
  end

  it "triggers the indexer" do
    subject.indexer.should_receive(:setup)
    subject.indexer.should_receive(:start)
    subject.run
  end

end
