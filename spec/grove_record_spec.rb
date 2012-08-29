require 'sherlock/grove_record'

describe Sherlock::GroveRecord do

  describe "#expand" do

    subject { Sherlock::GroveRecord.new({'uid' => 'post.card:hell.flames$1234'}) }

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
        'label_2_' => '<END>',
        'oid_' => '1234'
      }
      subject.expand.should eq(expected)
    end

  end

  describe "#flatten" do 

    let(:payload) {
      { 'uid' => 'post.card:hell.flames$1234',
        'attributes' => {
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
    }

    subject {
      Sherlock::GroveRecord.new(payload)
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
