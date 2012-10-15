require 'spec_helper'

describe Sherlock::UidOriginIdentifier do

  it "correctly identifies dittforslag uids" do
    Sherlock::UidOriginIdentifier.dittforslag?('post:mittap.dittforslag.xyzzy$1').should be_true
    Sherlock::UidOriginIdentifier.dittforslag?('post.card:mittap.dittforslag.xyzzy$1').should be_true
    Sherlock::UidOriginIdentifier.dittforslag?('post:zmittap.dittforslag.xyzzy$1').should be_false
    Sherlock::UidOriginIdentifier.dittforslag?('post.card:mittap.dittforslagz.xyzzy$1').should be_false
  end

  it "correctly identifies origami uids" do
    ['affiliation', 'associate', 'capacity', 'group', 'note', 'organization', 'unit'].each do |klass|
      Sherlock::UidOriginIdentifier.origami?("#{klass}:this.that.$1").should be_true
      Sherlock::UidOriginIdentifier.origami?("#{klass}.xyzzy:this.that.$1").should be_true
      Sherlock::UidOriginIdentifier.origami?("z#{klass}:this.that.$1").should be_false
      Sherlock::UidOriginIdentifier.origami?("z#{klass}.xyzzy:this.that.$1").should be_false
    end
  end

  it "correctly identifies grove uids" do
    Sherlock::UidOriginIdentifier.grove?("post:this.that.$1").should be_true
    Sherlock::UidOriginIdentifier.grove?("post.card:this.that.$1").should be_true
    Sherlock::UidOriginIdentifier.grove?("zpost:this.that.$1").should be_false
    Sherlock::UidOriginIdentifier.grove?("postz.card:this.that.$1").should be_false
  end

end
