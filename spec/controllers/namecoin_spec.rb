RSpec.describe BlocksController, type: :controller do
  
  it "should get name" do
    get :name, name: "d/bitcoin"
    assigns(:name).should == "d/bitcoin"
    assigns(:names).should == [assigns(:current)]
    assigns(:current).hash.should == "47dd31eb02f8307b3f08d455fea850dfe66a6157"
    assigns(:current).value.should == "webpagedeveloper.me/namecoin"
  end

  it "should search for namecoin name" do
    get :search, search: "d/bitcoin"
    response.should redirect_to(name_path("d/bitcoin"))
  end

  it "should list recent names" do
    get :names
    assigns(:page).should == 1
    assigns(:max).should == 458
    assigns(:names).size.should == 20
    assigns(:names).first.hash.should == "45ef70fda7f5374097b46df40f5ad919911844cd"
    assigns(:names).last.name.should == "d/name"
  end

end
