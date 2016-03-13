RSpec.describe AddressController, type: :controller do

  render_views

  let(:block_hash) { "00000000007e2a0846b25e0a70b7a7560f5c07bdbff16f259711480f58b33675" }
  let(:tx_hash) { "ab1207bd605af57ed0b5325ac94d19578cff3bce668ebe8dda2f42a00b001f5d" }
  let(:address) { "NFGG6FCfnpWAB6DCyQuSFC612rnpYEgFBu" }

  it "should render html" do
    get :show, id: address
    response.status.should == 200
    assigns(:address).should == address
    assigns(:hash160).should == Bitcoin.hash160_from_address(address)
    assigns(:addr_txouts).count.should == 1
  end

  it "should render json" do
    get :show, id: address, format: :json
    response.status.should == 200
    res = JSON.parse(response.body)
    res['address'].should == address
    res['hash160'].should == Bitcoin.hash160_from_address(address)
    res['tx_in_sz'].should == 1
    res['tx_out_sz'].should == 1
    res['btc_in'].should == 106000000
    res['btc_out'].should == 106000000
    res['balance'].should == 0
    res['tx_sz'].should == 2
    res['transactions'].size.should == 2
  end

  it "should fail on invalid address" do
    get :show, id: "invalid_address"
    response.status.should == 200
    assigns(:error).should == "Address invalid_address is invalid."
  end

end
