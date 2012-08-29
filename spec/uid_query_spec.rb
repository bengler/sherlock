require 'sherlock/uid_query'

describe Sherlock::UIDQuery do
  context "fully qualified" do
    subject { Sherlock::UIDQuery.new('post.card:hell.flames$123') }

    specify {
      terms = {
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'label_0_' => 'hell',
        'label_1_' => 'flames',
        'oid_' => '123'
      }
      subject.filters.should eq({'filter' => {'terms' => terms, 'missing' => {'field' => 'label_2_'}}})
    }
  end

  context "fully specified, without oid" do
    subject { Sherlock::UIDQuery.new('post.card:hell.flames') }
    specify {
      terms = {
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'label_0_' => 'hell',
        'label_1_' => 'flames',
      }
      subject.filters.should eq({'filter' => {'terms' => terms, 'missing' => {'field' => 'label_2_'}}})
    }
  end

  context "with wildcard path" do
    subject { Sherlock::UIDQuery.new('post.card:hell.flames.*') }
    specify {
      terms = {
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'label_0_' => 'hell',
        'label_1_' => 'flames',
      }
      subject.filters.should eq({'filter' => {'terms' => terms}})
    }
  end

  context "with wildcard klass" do
    subject { Sherlock::UIDQuery.new('*:hell.flames') }
    specify {
      terms = {
        'label_0_' => 'hell',
        'label_1_' => 'flames',
      }
      subject.filters.should eq({'filter' => {'terms' => terms, 'missing' => {'field' => 'label_2_'}}})
    }
  end

  context "with wildcard klass and wildcard path" do
    subject { Sherlock::UIDQuery.new('*:hell.flames.*') }
    specify {
      terms = {
        'label_0_' => 'hell',
        'label_1_' => 'flames',
      }
      subject.filters.should eq({'filter' => {'terms' => terms}})
    }
  end

  context "with wildcard path and specified oid" do
    subject { Sherlock::UIDQuery.new('post.card:*$123') }
    specify {
      terms = {
        'klass_0_' => 'post',
        'klass_1_' => 'card',
        'oid_' => '123',
      }
      subject.filters.should eq({'filter' => {'terms' => terms}})
    }
  end
end
