RSpec.describe ScriptsController, type: :controller do

  let(:pk_script) { "OP_DUP OP_HASH160 a0d92e6183f508e401aaa5b058c63861bb3d4514 OP_EQUALVERIFY OP_CHECKSIG" }
  let(:script_sig) { "304502201427eced5b3bb60b7fcd677c5f3013c97a7339ba49874649e298e2b9e1e2257a0221008ac0f312f07ef83805f3c13b47ecf2f23a6da4310618dfefbd71131393e4e96f01 0399a0b5eb31db5b8e9babf8249a6accacbce667e1a7b3d806027d21711f3e73db" }
  let(:sig_hash) { "4b64f253615a173f60b260c819390b6d65e3257ef50846549c2bc53e6b797db9" }

  it "should execute input script given tx hash / index" do
    tx_hash = STORE.head.prev_block.tx.last.hash
    get :show, id: "#{tx_hash}:0"
    assigns(:tx).hash.should == tx_hash
    assigns(:result).should == true
    assigns(:debug).should be_a(Array)
  end

  it "should execute arbitrary script given pk_script / script_sig" do
    get :show, script_sig: "1 1 2", pk_script: "OP_DROP OP_DUP OP_EQUALVERIFY"
    assigns(:tx).should == nil
    assigns(:result).should == true
  end

  it "should execute arbitrary script with sighash" do
    get :show, script_sig: script_sig, pk_script: pk_script, sig_hash: sig_hash,
        verify_low_s: "0"
    assigns(:result).should == true
  end

  it "should fail when invalid sighash given" do
    get :show, script_sig: script_sig, pk_script: pk_script, sig_hash: "foobar"
    assigns(:result).should == false
  end

  it "should fail when signature is invalid" do
    s, p = script_sig.split(" "); s[140] = "a"; s[141] = "a"; script_sig = [s, p].join(" ")
    get :show, script_sig: script_sig, pk_script: pk_script, sig_hash: sig_hash
    assigns(:result).should == false
  end

  it "should fail when *VERIFY operation fails" do
    get :show, script_sig: "2", pk_script: "3 OP_EQUALVERIFY"
    assigns(:result).should == false
  end

  it "should ignore signatures when no sighash is given" do
    s, p = script_sig.split(" "); s[140] = "a"; s[141] = "a"; script_sig = [s, p].join(" ")
    get :show, script_sig: script_sig, pk_script: pk_script, sig_hash: "", verify_low_s: "0"
    assigns(:result).should == true
  end

  
  it "should verify minimaldata" do
    opts = { script_sig: "01", pk_script: "", sig_hash: "" }

    get :show, opts
    assigns(:result).should == false
    assigns(:debug).should == [[], :verify_minimaldata]

    get :show, opts.merge(verify_minimaldata: "0")
    assigns(:result).should == true
  end

  it "should verify sigpushonly" do
    opts = { script_sig: "1 OP_DROP 1", pk_script: "", sig_hash: "" }

    get :show, opts
    assigns(:result).should == false
    assigns(:debug).should == [[], :verify_sigpushonly]

    get :show, opts.merge(verify_sigpushonly: "0")
    assigns(:result).should == true
  end

  it "should verify cleanstack" do
    get :show, script_sig: "1 1", pk_script: "", sig_hash: ""
    assigns(:result).should == false
    assigns(:debug).should == [[], "OP_1", [1], "OP_1", [1, 1], "OP_CODESEPARATOR", [1, 1], "RESULT", [1], :verify_cleanstack]

    get :show, script_sig: "1 1", pk_script: "", sig_hash: "", verify_cleanstack: "0"
    assigns(:result).should == true
  end

  it "should verify low_s" do
    opts = { script_sig: script_sig, pk_script: pk_script, sighash: sig_hash }

    get :show, opts
    assigns(:result).should == false

    get :show, opts.merge(verify_low_s: "0")
    assigns(:result).should == true
  end

end
