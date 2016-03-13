RSpec.describe SearchController, type: :controller do

  let(:block_hash) { "00000000007e2a0846b25e0a70b7a7560f5c07bdbff16f259711480f58b33675" }
  let(:tx_hash) { "ab1207bd605af57ed0b5325ac94d19578cff3bce668ebe8dda2f42a00b001f5d" }
  let(:address) { "NFGG6FCfnpWAB6DCyQuSFC612rnpYEgFBu" }

  it "should search for block by hash" do
    get :search, search: block_hash
    response.should redirect_to(block_path(block_hash))
  end

  it "should search for block by height" do
    block = STORE.block_at_height(123)
    get :search, search: 123
    response.should redirect_to(block_path(block.hash))
  end

  it "should search for tx by hash" do
    get :search, search: tx_hash
    response.should redirect_to(tx_path(tx_hash))
  end

  it "should search for tx by nhash" do
    tx = STORE.tx(tx_hash)
    get :search, search: tx.nhash
    response.should redirect_to(tx_path(tx_hash))
  end

  it "should search for address" do
    get :search, search: address

    response.should redirect_to(address_path(address))
  end

  it "should search for namecoin name" do
    get :search, search: "d/bitcoin"
    response.should redirect_to(name_path("d/bitcoin"))
  end

  it "should render error when nothing found" do
    get :search, search: "nonexistant"
    assigns(:error).should == "Nothing matches nonexistant."
  end

end
