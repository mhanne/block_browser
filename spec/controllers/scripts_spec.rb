RSpec.describe BlocksController, type: :controller do

  it "should list scripts of certain type" do
    get :scripts, type: "pubkey"
    assigns(:offset).should == 0
    assigns(:limit).should == 20
    assigns(:count).should == 958
    assigns(:txouts).count.should == 20
    txout = assigns(:txouts).to_a.last

    get :scripts, type: "pubkey", offset: 19
    assigns(:offset).should == 19
    assigns(:count).should == 958
    assigns(:txouts).to_a.first.should == txout
  end

  # TODO
  it "should list p2sh scripts of certain inner script type" do
    get :p2sh_scripts, type: "unknown"
    assigns(:txins).count.should == 0
  end

end
