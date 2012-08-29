require 'eson-dsl'
describe 'eson-dsl' do
  it "works" do
    query = {
      :query => {
        :filtered => {
          :query => {
            :query_string => {
              :query => "hot"
            }
          },
          :filter => [
            {
              :bool => {
                :must => [
                  {:term => { "label_0_" => "hell"}},
                  {:term => { "label_1_" => 'flames'}}
                ]
              }
            },
            {
              'and' => {
                :missing => {
                  :field => "label_2_"
                }
              }
            }
          ]
        }
      }
    }

    q = Eson::Search::BaseQuery.new do
      query do
        query_string :query => 'hot'
      end

      filter do |f|
        bool do
          must do
            {'label_0_' => 'hell', 'label_1_' => 'flames'}.each do |key, value|
              term key => value
            end
          end
        end
        f.and do
          missing :field => 'label_2_'
        end
      end
    end

    #result = q.to_query_hash.merge(:size => 1, :from => 1)
    result = q.to_query_hash
    q.to_query_hash.should eq(query)
  end
end
