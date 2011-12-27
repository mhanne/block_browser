class BlocksController < ApplicationController

  layout 'application'

  def index
    @per_page = 20
    depth = STORE.get_depth
    depth = params[:depth].to_i  if params[:depth] && params[:depth].to_i < depth
    depth = @per_page  if depth < @per_page
    @blocks = []
    if STORE.db.class.name =~ /Sequel/
      @blocks = STORE.db[:blk].select(:hash, :depth).filter("depth <= ?", depth).order(:depth).limit(@per_page).reverse
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
    respond_to do |format|
      format.html { @page_title = "Address Details" }
      format.json do
        render(:text => @txouts.map {|o| [o, o.get_next_in]}
          .flatten.compact.map(&:get_tx).to_json)
      end
    end
  end

  caches_page :script
  def script
    tx_hash, txin_idx = params[:id].split(":")
    @tx = STORE.get_tx(tx_hash)
    @txin = @tx.in[txin_idx.to_i]
    @txout = @txin.get_prev_out
    @script = Bitcoin::Script.new(@txin.script_sig + @txout.pk_script)
    @result = @script.run do |pubkey, sig, hash_type|
      hash = @tx.signature_hash_for_input(@txin.tx_idx, nil, @txout.pk_script)
      Bitcoin.verify_signature(hash, sig, pubkey.unpack("H*")[0])
    end
    @debug = @script.debug
    @page_title = "Script Details"
  end

  # search for given (part of) block/tx/address.
  # also try to account for 'half bytes' when hex string is cut off.
  def search
    @id = params[:search]
    if Bitcoin.valid_address?(@id)
      return redirect_to address_path(@id)
    elsif STORE.db.class.name =~ /Sequel/
      if @id.size % 2 == 0
        return  if search_block(@id)
        return  if search_tx(@id)
        t = @id.split; t.pop; t.shift; t = t.join
        return  if search_block(t)
        return  if search_tx(t)
      else
        return  if search_block(@id[0..-2])
        return  if search_block(@id[1..-1])
        return  if search_tx(@id[0..-2])
        return  if search_tx(@id[1..-1])
      end
    elsif @id =~ /^0000/
      redirect_to block_path(@id)
    else
      redirect_to tx_path(@id)
    end
    render :text => "NOT FOUND"
  end

  def unconfirmed
    @tx = STORE.get_unconfirmed_tx
    respond_to do |format|
      format.html { @page_title = "Unconfirmed Tx (#{@tx.size})" }
      format.json { render :text => @tx.map(&:to_hash).to_json }
    end
  end

  private

  def search_block(part)
    blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    hash = STORE.db[:blk].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    redirect_to block_path(hash)
  rescue
    nil
  end

  def search_tx(part)
    blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    hash = STORE.db[:tx].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    redirect_to tx_path(hash)
  rescue
    nil
  end

end
