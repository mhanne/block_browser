class BlocksController < ApplicationController

  layout 'application'

  def index
    @blocks = Block.order("depth DESC").paginate(:per_page => 25, :page => params[:page] || 1)
    @page_title = "Recent Blocks"
  end

  def show
    @block = Block.get(params[:id])
    @page_title = "Block Details"
  end

end
