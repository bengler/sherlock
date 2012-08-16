require 'sherlock'

describe Sherlock do

  subject { Sherlock.new }

  it "configures" do
    Sherlock.stub(:environment => 'production')
    Sherlock.config['grove'].should eq('session' => 'abc', 'host' => 'grove.o5.no')
  end

  it "adds stream groups" do
    subject.stream_groups << 'hello'
    subject.stream_groups.should eq(['hello'])
  end

  it "sets up each group and triggers processing" do
    one = stub
    two = stub
    subject.stream_groups << one << two
    one.should_receive(:setup)
    one.should_receive(:start)

    two.should_receive(:setup)
    two.should_receive(:start)

    subject.run
  end

end
