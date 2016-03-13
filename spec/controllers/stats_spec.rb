RSpec.describe StatsController, type: :controller do

  it "should display stats" do
    get :stats
    response.status.should == 200
  end

end
