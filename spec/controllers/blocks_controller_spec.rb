require 'spec_helper'

describe BlocksController do

  render_views

  let(:block_hash) { "000000008cd4b1bdaa1278e3f1708258f862da16858324e939dc650627cd2e27" }  
  let(:tx_hash) { "5872025cffc8894b116d5091bbc33986f23305d7b02c069f3eb7918a7e353e67" }

  describe :index do

    it "should render html" do
      get :index
      response.status.should == 200
      assigns(:blocks).count.should == 20
      assigns(:blocks).first[:hash].hth.should == block_hash
    end

  end
  
  describe :block do

    it "should render html" do
      get :block, id: block_hash
      response.status.should == 200
      assigns(:block).hash.should == block_hash
    end
      
    it "should render json" do
      get :block, id: block_hash, format: :json
      response.status.should == 200
      JSON.parse(response.body).should == STORE.get_block(block_hash).to_hash
    end

    it "should render bin" do
      get :block, id: block_hash, format: :bin
      response.status.should == 200
      response.body.should == STORE.get_block(block_hash).to_payload
    end

    it "should render hex" do
      get :block, id: block_hash, format: :hex
      response.status.should == 200
      response.body.should == STORE.get_block(block_hash).to_payload.hth
    end

  end

  describe :tx do

    it "should render html" do
      get :tx, id: tx_hash
      response.status.should == 200
      assigns(:tx).hash.should == tx_hash
    end

    it "should render json" do
      get :tx, id: tx_hash, format: :json
      response.status.should == 200
      JSON.parse(response.body).should == STORE.get_tx(tx_hash).to_hash(with_nid: true)
    end

    it "should render bin" do
      get :tx, id: tx_hash, format: :bin
      response.status.should == 200
      response.body.should == STORE.get_tx(tx_hash).to_payload
    end

    it "should render hex" do
      get :tx, id: tx_hash, format: :hex
      response.status.should == 200
      response.body.should == STORE.get_tx(tx_hash).to_payload.hth
    end

  end

  describe :address do

    let(:address) { "n2ESto3LRX8U7k7CxfLVac2eSaTvp98pni" }

    it "should render html" do
      get :address, id: address
      response.status.should == 200
      assigns(:address).should == address
      assigns(:hash160).should == Bitcoin.hash160_from_address(address)
      assigns(:addr_txouts).count.should == 20
    end

    it "should render json" do
      get :address, id: address, format: :json
      response.status.should == 200
      res = JSON.parse(response.body)
      res['address'].should == address
      res['hash160'].should == Bitcoin.hash160_from_address(address)
      res['tx_in_sz'].should == 20
      res['tx_out_sz'].should == 20
      res['btc_in'].should == 12431302
      res['btc_out'].should == 12431302
      res['balance'].should == 0
      res['tx_sz'].should == 38
      res['transactions'].size.should == 38
    end

    it "should fail on invalid address" do
      get :address, id: "invalid_address"
      response.status.should == 200
      assigns(:error).should == "Address invalid_address is invalid."
    end

  end

  describe :script do

    let(:pk_script) { "OP_DUP OP_HASH160 a0d92e6183f508e401aaa5b058c63861bb3d4514 OP_EQUALVERIFY OP_CHECKSIG" }
    let(:script_sig) { "304502201427eced5b3bb60b7fcd677c5f3013c97a7339ba49874649e298e2b9e1e2257a0221008ac0f312f07ef83805f3c13b47ecf2f23a6da4310618dfefbd71131393e4e96f01 0399a0b5eb31db5b8e9babf8249a6accacbce667e1a7b3d806027d21711f3e73db" }
    let(:sig_hash) { "4b64f253615a173f60b260c819390b6d65e3257ef50846549c2bc53e6b797db9" }

    it "should execute input script given tx hash / index" do
      tx_hash = STORE.get_head.tx.last.hash
      get :script, id: "#{tx_hash}:0"
      assigns(:tx).hash.should == tx_hash
      assigns(:result).should == true
      assigns(:debug).should be_a(Array)
    end

    it "should execute arbitrary script given pk_script / script_sig" do
      get :script, script_sig: "1 1 2", pk_script: "OP_DROP OP_DUP OP_EQUALVERIFY"
      assigns(:tx).should == nil
      assigns(:result).should == true
    end

    it "should execute arbitrary script with sighash" do
      get :script, script_sig: script_sig, pk_script: pk_script, sig_hash: sig_hash
      assigns(:result).should == true
    end

    it "should fail when invalid sighash given" do
      get :script, script_sig: script_sig, pk_script: pk_script, sig_hash: "foobar"
      assigns(:result).should == false
    end

    it "should fail when signature is invalid" do
      s, p = script_sig.split(" "); s[140] = "a"; s[141] = "a"; script_sig = [s, p].join(" ")
      get :script, script_sig: script_sig, pk_script: pk_script, sig_hash: sig_hash
      assigns(:result).should == false
    end

    it "should ignore signatures when no sighash is given" do
      s, p = script_sig.split(" "); s[140] = "a"; s[141] = "a"; script_sig = [s, p].join(" ")
      get :script, script_sig: script_sig, pk_script: pk_script, sig_hash: ""
      assigns(:result).should == true
    end

  end

  describe :scripts do

    it "should list scripts of certain type" do
      get :scripts, type: "pubkey"
      assigns(:offset).should == 0
      assigns(:limit).should == 20
      assigns(:count).should == 500
      assigns(:txouts).count.should == 20
      txout = assigns(:txouts).to_a.last

      get :scripts, type: "pubkey", offset: 19
      assigns(:offset).should == 19
      assigns(:count).should == 500
      assigns(:txouts).to_a.first.should == txout
    end

    # TODO
    it "should list p2sh scripts of certain inner script type" do
      get :p2sh_scripts, type: "unknown"
      assigns(:txins).count.should == 0
    end

  end

  describe :search do

    it "should search for block by hash" do
      get :search, search: block_hash
      response.should redirect_to(block_path(block_hash))
    end

    it "should search for block by depth" do
      block = STORE.get_block_by_depth(123)
      get :search, search: 123
      response.should redirect_to(block_path(block.hash))
    end

    it "should search for tx by hash" do
      get :search, search: tx_hash
      response.should redirect_to(tx_path(tx_hash))
    end

    it "should search for tx by nhash" do
      tx = STORE.get_tx(tx_hash)
      get :search, search: tx.nhash
      response.should redirect_to(tx_path(tx_hash))
    end

    it "should search for address" do
      address = "mrf5iYUrgE2qePqpbjJ5bDCLcUWCRYAETT"
      get :search, search: address
      response.should redirect_to(address_path(address))
    end

  end

  describe :stats do

    it "should display stats" do
      get :stats
      response.status.should == 200
    end

  end

  describe :relay do

    include Bitcoin::Builder

    before do
      run_bitcoin_node
      @tx = build_tx do |t|
        t.input do |i|
          i.prev_out @fake_chain.store.get_head.tx.first.out.first.get_tx, 0
          i.signature_key @key
        end
        t.output do |o|
          o.value 12345
          o.to @key.addr
        end
      end
    end

    after do
      kill_bitcoin_node
    end

    let(:tx) { Bitcoin::P::Tx.new }

    it "should relay transaction to the bitcoin network" do
      post :relay_tx, tx: @tx.payload.hth, wait: 0
      assigns(:error).should == nil
      res = assigns(:result)
      res["success"].should == true
      res["hash"].should == @tx.hash
    end

    it "should fail when it cannot decode the tx" do
      post :relay_tx, tx: "something_weird"
      assigns(:error).should == "Error decoding transaction."
    end

    it "should fail when tx syntax is invalid" do
      @tx.instance_eval { @in = [] }
      post :relay_tx, tx: @tx.to_payload.hth, wait: 0
      assigns(:error).should == "Transaction syntax invalid."
      assigns(:result)["error"].should == "Transaction syntax invalid."
      assigns(:result)["details"].should == ["lists", [0, 1]]
    end

    it "should fail when tx context is invalid" do
      @tx.instance_eval { @in[0].prev_out = "\x00"*32 }
      post :relay_tx, tx: @tx.to_payload.hth, wait: 0
      assigns(:error).should == "Transaction context invalid."
      assigns(:result)["details"].should == ["prev_out", [["0000000000000000000000000000000000000000000000000000000000000000", 0]]]
    end

    it "should accept tx data as json" do
      post :relay_tx, tx: @tx.to_json, wait: 0
      assigns(:result)["hash"].should == @tx.hash
    end

    it "should respond in json format" do
      post :relay_tx, tx: @tx.to_json, wait: 0, format: :json
      JSON.parse(response.body).should == {"success" => true,
        "hash" => @tx.hash, "propagation" => {"received" => 0, "sent" => 1, "percent" => 0.0}}
    end

    it "should return error in json format" do
      post :relay_tx, tx: "foobar", wait: 0, format: :json
      JSON.parse(response.body).should == {"error" => "Error decoding transaction."}
    end

  end

end
