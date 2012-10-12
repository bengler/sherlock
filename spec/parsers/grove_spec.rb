require 'sherlock/parsers/grove'
require 'spec_helper'

describe Sherlock::Parsers::Grove do

  describe "#build_records" do

    let(:uid) {
      'post.card:hell.tools.pitchfork$1'
    }

    let(:attributes) {
      {
        'document' => {'app' => 'hot'},
        'paths' => ["hell.trademarks.pitchfork", "hell.tools.pitchfork"],
        'id' => uid
      }
    }

    it "conserves a non-flattened copy of document" do
      records = Sherlock::Parsers::Grove.build_records('post.card:hell.flames$1234', attributes)
      records.count.should eq 2
      records.first['pristine'].should eq attributes
    end

    context "restricted" do

      it "add restricted attribute if none is present" do
        records = Sherlock::Parsers::Grove.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be false
      end

      it "keep restricted attribute" do
        attributes['restricted'] = false
        records = Sherlock::Parsers::Grove.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be false

        attributes['restricted'] = true
        records = Sherlock::Parsers::Grove.build_records('post.card:hell.flames$1234', attributes)
        records.first['restricted'].should be true
      end

    end

  end

  describe "#expand" do

    subject { Sherlock::Parsers::Grove.new('post.card:hell.flames$1234', {}) }

    its(:klass) { should eq('post.card') }
    its(:path) { should eq('hell.flames') }
    its(:oid) { should eq('1234') }
    its(:realm) { should eq('hell') }

    it "expands metadata" do
      expected = {
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'label_0_' => 'hell',
        'label_1_' => 'flames',
        'oid_' => '1234'
      }
      subject.expand.should eq(expected)
    end

  end

  describe "#flatten" do

    let(:record) {
      {
        'document' => {
          'a' => 1,
          'b' => 2,
          'c' => {
            'd' => 3,
            'e' => 4
          }
        }
      }
    }

    subject {
      Sherlock::Parsers::Grove.new('post.card:hell.flames$1234', record)
    }

    it "flattens a document hash" do
      expected = {
        'document.a' => 1,
        'document.b' => 2,
        'document.c.d' => 3,
        'document.c.e' => 4
      }
      subject.flatten.should eq expected
    end

  end

end
