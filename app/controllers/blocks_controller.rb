class BlocksController < ApplicationController

  layout 'application'

  def index
    @per_page = 20
    depth = STORE.get_depth
    depth = params[:depth].to_i  if params[:depth] && params[:depth].to_i < depth
    depth = @per_page  if depth < @per_page
    @blocks = []
    if STORE.db.class.name =~ /Sequel/
      @blocks = STORE.db[:blk].order(:depth).limit(@per_page).map do |blk|
        STORE.send(:wrap_block, blk)
      end
    else
      @per_page.times { @blocks << STORE.get_block_by_depth(depth); depth -= 1 }
    end
    @page_title = "Recent Blocks"
  end

  def block
    @block = STORE.get_block(params[:id])
    return render :text => "Block #{params[:id]} not found."  unless @block
    respond_to do |format|
      format.html { @page_title = "Block Details" }
      format.json { render :text => @block.to_json }
      format.bin { render :text => @block.to_payload }
    end
  end

  def tx
    @tx = STORE.get_tx(params[:id])
    return render :text => "Tx #{params[:id]} not found."  unless @tx
    respond_to do |format|
      format.html { @page_title = "Transaction Details" }
      format.json { render :text => @tx.to_json }
      format.bin { render :text => @tx.to_payload }
    end
  end

  def address
    @address = params[:id]
    unless Bitcoin.valid_address?(@address)
      return render :text => "Address #{params[:id]} is invalid."
    end
    @hash160 = Bitcoin.hash160_from_address(@address)
    @txouts = STORE.get_txouts_for_hash160(@hash160)
    @page_title = "Address Details"
  end

  def script
    tx_hash, txin_idx = params[:id].split(":")
    @tx = STORE.get_tx(tx_hash)
    @txin = @tx.in[txin_idx.to_i]
    @txout = @txin.get_prev_out
    @script = Bitcoin::Script.new(@txin.script_sig + @txout.pk_script)
    @debug = []
    @result = @script.run(@debug) do |pubkey, sig, hash_type|
      hash = @tx.signature_hash_for_input(@txin.tx_idx, nil, @txout.pk_script)
      Bitcoin.verify_signature(hash, sig, pubkey.unpack("H*")[0])
    end
    @page_title = "Script Details"
  end

end
