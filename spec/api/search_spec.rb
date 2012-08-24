require "spec_helper"

describe 'API v1 search' do

  describe "GET /search/:realm/:query" do

    it 'finds stuff' do
      # uid = 'post:realm.some.path$l0ngAndFiNeUId4Utoo'
      # Score.create!(:external_uid => uid, :kind => 'kudos')
      # get "/scores/#{uid}/kudos"
      # score = JSON.parse(last_response.body)["score"]
      # score["external_uid"].should eq(uid)
    end
  end

end
