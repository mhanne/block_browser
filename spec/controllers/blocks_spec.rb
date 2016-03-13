RSpec.describe BlocksController, type: :controller do

  render_views

  let(:block_hash) { "00000000007e2a0846b25e0a70b7a7560f5c07bdbff16f259711480f58b33675" }

  it "should render index" do
    get :index
    response.status.should == 200
    assigns(:blocks).count.should == 20
    assigns(:blocks).first[:hash].hth.should == block_hash
  end

  it "should render html" do
    get :show, id: block_hash
    response.status.should == 200
    assigns(:block).hash.should == block_hash
  end
  
  it "should render json" do
    get :show, id: block_hash, format: :json
    response.status.should == 200
    JSON.parse(response.body).should == STORE.block(block_hash).to_hash(with_next_block: true, with_nid: true, with_address: true, with_next_in: true)
  end

  it "should render bin" do
    get :show, id: block_hash, format: :bin
    response.status.should == 200
    response.body.should == STORE.block(block_hash).to_payload
  end

  it "should render hex" do
    get :show, id: block_hash, format: :hex
    response.status.should == 200
    response.body.should == STORE.block(block_hash).to_payload.hth
  end

  it "should display block containing tx with OP_RETURN output script type" do
    block_hash = "00000000004f9e2bfeb67af0b07d8fc5cfb7779f3a1a9065e5a47ce1dd6dea59"
    get :show, id: block_hash
    response.should be_success
    assigns(:block).hash.should == block_hash
    response.body.should =~ /OP_RETURN \(provably burned\)/
  end

end
