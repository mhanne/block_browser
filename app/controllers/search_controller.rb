class SearchController < ApplicationController

  # search for given (part of) block/tx/address.
  # TODO: search for partial data
  # TODO: search for pubkeys/hash160
  def search
    @id = params[:search]
    if Bitcoin.valid_address?(@id)
      return redirect_to address_path(@id)
    elsif @id.to_i.to_s == @id
      block = STORE.block_at_height(@id.to_i)
      return redirect_to(block_path(block.hash))  if block
    elsif STORE.is_a?(Blockchain::Backends::SequelBase)
      return  if search_block(@id)
      return  if search_tx(@id)
      return  if search_name(@id)
    end
    render_error("Nothing matches #{@id}.", 404)
  end

  private
  
  def search_block(part)
    # blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    # hash = STORE.db[:blk].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    hash = STORE.db[:blk][hash: part.htb.to_sequel_blob][:hash].hth
    redirect_to block_path(hash)
  rescue
    nil
  end

  def search_tx(part)
    # blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    # hash = STORE.db[:tx].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    tx = STORE.db[:tx][hash: part.htb.blob]
    tx ||= STORE.db[:tx][nhash: part.htb.blob]
    redirect_to tx_path(tx[:hash].hth)
  rescue
    nil
  end

  def search_name(part)
    return nil  unless Bitcoin.namecoin?
    name = STORE.name_show(part)
    redirect_to name_path(name.name)  if name
  rescue
    nil
  end

end
