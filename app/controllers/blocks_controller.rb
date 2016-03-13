require 'timeout'
require 'method_source'

class BlocksController < ApplicationController

  def index
    @per_page = 20
    STORE.instance_eval { @head = nil }
    height = STORE.height
    height = params[:height].to_i  if params[:height] && params[:height].to_i < height
    height = (@per_page - 1)  if height < @per_page
    @blocks = STORE.db[:blk].filter("height <= ?", height).where(chain: 0).order(:height).limit(@per_page).reverse
    @page_title = "Recent Blocks"
  end

  def show
    @block = STORE.block(params[:id])
    return render_error("Block #{params[:id]} not found.")  unless @block
    @siblings = STORE.db[:blk].where(prev_hash: @block.prev_block_hash.blob)
                .reject {|b| b[:id] == @block.id }
                .map {|b| STORE.wrap_block(b) }
    @page_title = "Block Details"
    respond_with(@block, with_next_block: true, with_nid: true, with_address: true, with_next_in: true)
  end

end
