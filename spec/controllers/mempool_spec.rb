require 'spec_helper'

describe BlocksController do

  describe :mempool do

    render_views

    include Bitcoin::Builder

    before do
      `rm spec/tmp/fake_chain.db`
      setup_fake_chain

      v = $VERBOSE; $VERBOSE = nil
      STORE = Bitcoin::Blockchain.create_store(:sequel, db: @store.db.uri)
      p STORE.db.uri
      MEMPOOL = Bitcoin::Blockchain::Mempool.new(STORE, db: STORE.db.uri)
      $VERBOSE = v

      # a valid transaction
      @tx = build_tx do |t|
        t.input {|i| i.prev_out @fake_chain.store.get_head.tx[0], 0; i.signature_key @fake_chain.key }
        t.output {|o| o.value 50e8; o.to @fake_chain.key.addr }
      end

      @invalid_tx = build_tx do |t|
        t.input {|i| i.prev_out @fake_chain.store.get_head.get_prev_block.tx[0], 0 }
        t.output {|o| o.value 50e8; o.to @fake_chain.key.addr }
      end

      # tx doublespending the first valid one
      @doublespend_tx = build_tx do |t|
        t.input {|i| i.prev_out @fake_chain.store.get_head.tx[0], 0; i.signature_key @fake_chain.key }
        t.output {|o| o.value 50e8; o.to Bitcoin::Key.generate.addr }
      end

      # a tx spending the first one to form a chain of unconfirmed txs
      @chain_tx = build_tx do |t|
        t.input {|i| i.prev_out @tx, 0; i.signature_key @fake_chain.key }
        t.output {|o| o.value 50e8; o.to Bitcoin::Key.generate.addr }
      end

      MEMPOOL.add(@tx)
      MEMPOOL.add(@chain_tx)
      MEMPOOL.add(@doublespend_tx)
      MEMPOOL.add(@invalid_tx)
    end

    describe :list do

      it "should display empty mempool" do
        MEMPOOL = Bitcoin::Blockchain::Mempool.new(STORE, db: "sqlite:/")
        get :mempool, type: :all
        response.should be_ok
        assigns(:txs).should == []
      end

      it "should list all transactions" do
        get :mempool, type: :all
        response.should be_ok
        assigns(:txs).map(&:hash).should == [@invalid_tx.hash, @doublespend_tx.hash, @chain_tx.hash, @tx.hash]
      end

      it "should list only accepted transactions" do
        get :mempool, type: :accepted
        response.should be_ok
        assigns(:txs).map(&:hash).should == [@chain_tx.hash, @tx.hash]
      end

      it "should list only rejected transactions" do
        get :mempool, type: :rejected
        response.should be_ok
        assigns(:txs).map(&:hash).should == [@invalid_tx.hash]
      end

      describe :doublespend do

        it "should highlight doublespent txs in list" do
          get :mempool, type: :accepted
          response.body.should =~ /<tr class='even accepted doublespent' id='mempool_#{@tx.hash}'>/
        end

        it "should list doublespends" do
          get :mempool, type: :doublespend
          response.should be_ok
          assigns(:txs).map(&:hash).should == [@doublespend_tx.hash]
        end

      end

    end

    describe :show do

      it "should display mempool tx" do
        get :mempool_tx, id: @tx.hash
        response.should be_ok
        assigns(:tx).hash.should == @tx.hash
      end

      it "should link to prev out in block" do
        get :mempool_tx, id: @tx.hash
        response.body.should =~ /<a href="\/tx\/#{@tx.in[0].prev_out.reverse.hth}"/
      end

      it "should link to prev out in mempool" do
        get :mempool_tx, id: @chain_tx.hash
        response.body.should =~ /<a href="\/mempool_tx\/#{@tx.hash}"/
      end

      it "should calculate priority" do
        extend ActionView::Helpers::NumberHelper
        get :mempool_tx, id: @tx.hash
        priority_str = number_with_delimiter MEMPOOL.get(@tx.hash).priority
        response.body =~ /<th>Priority<\/th>\s<td>#{priority_str}<\/td>/
      end

      it "should redirect to confirmed tx" do
        @fake_chain.add_tx(@tx)
        @fake_chain.new_block
        MEMPOOL.confirmed_txs([@tx.hash])
        get :mempool_tx, id: @tx.hash
        response.should redirect_to(tx_path(@tx.hash))
      end

      # # TODO: namecoin doesn't support script_hash
      # it "should display tx with script_hash-type output" do
      #   tx = build_tx do |t|
      #     t.input {|i| i.prev_out @fake_chain.store.get_head.tx[0], 0; i.signature_key @fake_chain.key }
      #     t.output {|o| o.value 50e8; o.to Bitcoin.hash160(@fake_chain.key.pub), :script_hash }
      #   end
      #   MEMPOOL.add(tx)
      #   get :mempool_tx, id: tx.hash
      #   response.should be_ok
      # end

      describe :doublespend do

        it "should display doublespend tx" do
          get :mempool_tx, id: @doublespend_tx.hash
          response.should be_ok
          assigns(:tx).hash.should == @doublespend_tx.hash
        end

        it "should link doublespends" do
          get :mempool_tx, id: @tx.hash
          response.body.should =~ /<tr class='doublespent'>\s<th>Doublespend<\/th>\s<td>\s<a href="\/mempool_tx\/#{@doublespend_tx.hash}">#{@doublespend_tx.hash}<\/a>\s<br>\s<\/td>\s<\/tr>/

          get :mempool_tx, id: @doublespend_tx.hash
          response.body.should =~ /<tr class='doublespent'>\s<th>Doublespend<\/th>\s<td>\s<a href="\/mempool_tx\/#{@tx.hash}">#{@tx.hash}<\/a>\s<\/td>\s<\/tr>/
        end

        # # TODO
        # it "should link confirmed doublespend tx" do
        #   @fake_chain.add_tx(@tx)
        #   @fake_chain.new_block
        #   MEMPOOL.confirmed_txs([@tx.hash])
        #   get :mempool_tx, id: @doublespend_tx.hash
        #   binding.pry
        #   response.body.should =~ /<tr class='doublespent'>\s<th>Doublespend<\/th>\s<td>\s<a href="\/mempool_tx\/#{@tx.hash}">#{@tx.hash}<\/a>\s<\/td>\s<\/tr>/
        # end

      end

      describe :dependent do

        it "should link transactions this one depends on" do
          get :mempool_tx, id: @chain_tx.hash
          response.body.should =~ /<tr class='depends'>\s<th>Depends on<\/th>\s<td>\s<a href="\/mempool_tx\/#{@tx.hash}">#{@tx.hash}<\/a>\s<br>\s<\/td>\s<\/tr>/
        end

        it "should link transactions that depend on this one" do
          get :mempool_tx, id: @tx.hash
          response.body.should =~ /<tr class='depending'>\s<th>Depending<\/th>\s<td>\s<a href="\/mempool_tx\/#{@chain_tx.hash}">#{@chain_tx.hash}<\/a>\s<br>\s<\/td>\s<\/tr>/
          
        end

      end

    end

  end

end
