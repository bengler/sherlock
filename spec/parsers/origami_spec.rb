require 'sherlock/parsers/origami'
require 'spec_helper'

describe Sherlock::Parsers::Origami do

  describe "#build_records" do

    let(:uid) {
      'post.card:hell.tools.pitchfork$1'
    }

    it "conserves a non-flattened copy of document" do
      records = Sherlock::Parsers::Origami.build_records('post.card:hell.flames$1234', attributes)
      records.count.should eq 1
      records.first['pristine'].should eq attributes
    end

    context "restricted" do

      it "add restricted attribute if none is present" do
        records = Sherlock::Parsers::Origami.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be false
      end

      it "keep restricted attribute" do
        attributes['restricted'] = false
        records = Sherlock::Parsers::Origami.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be false

        attributes['restricted'] = true
        records = Sherlock::Parsers::Origami.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be true
      end

    end

  end



end
