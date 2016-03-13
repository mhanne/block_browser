RSpec.describe TxController, type: :controller do

  render_views

  let(:block_hash) { "00000000007e2a0846b25e0a70b7a7560f5c07bdbff16f259711480f58b33675" }
  let(:tx_hash) { "ab1207bd605af57ed0b5325ac94d19578cff3bce668ebe8dda2f42a00b001f5d" }
  let(:address) { "NFGG6FCfnpWAB6DCyQuSFC612rnpYEgFBu" }

  it "should render html" do
    get :show, id: tx_hash
    response.status.should == 200
    assigns(:tx).hash.should == tx_hash
  end

  it "should render json" do
    get :show, id: tx_hash, format: :json
    response.status.should == 200
    tx_data = STORE.tx(tx_hash).to_hash(with_nid: true, with_address: true, with_next_in: true).merge(
      "block" => "0000000000020cbf6a9ad040c1bae5fae99f382ce104aac898622c0c218069b9",
      "blocknumber" => 142,
      "time" => "2011-04-21 05:44:30"
    )
    JSON.parse(response.body).should == tx_data
  end

  it "should render bin" do
    get :show, id: tx_hash, format: :bin
    response.status.should == 200
    response.body.should == STORE.tx(tx_hash).to_payload
  end

  it "should render hex" do
    get :show, id: tx_hash, format: :hex
    response.status.should == 200
    response.body.should == STORE.tx(tx_hash).to_payload.hth
  end

  it "should display tx with OP_RETURN output script type" do
    tx_hash = "496b728d51d8d6030035779f6c588f519a0fd1ab2eaaa1ceb5924122bf8c68d5"
    get :show, id: tx_hash
    response.should be_success
    assigns(:tx).hash.should == tx_hash
    response.body.should =~ /\(No data\)/
  end

end
