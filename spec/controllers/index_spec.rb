RSpec.describe BlocksController, type: :controller do

  render_views
  
  let(:block_hash) { "00000000007e2a0846b25e0a70b7a7560f5c07bdbff16f259711480f58b33675" }

  it "should render html" do
    get :index
    response.status.should == 200
    assigns(:blocks).count.should == 20
    assigns(:blocks).first[:hash].hth.should == block_hash
  end

end
