require 'spec_helper'

describe BlocksController do

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
