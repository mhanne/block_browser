class NamesController < ApplicationController

  def index
    @per_page = 20
    @page = (params[:page] || 1).to_i
    @offset = @per_page * (@page - 1)
    @max = STORE.db[:names].count
    @names = STORE.db[:names].order(:txout_id).reverse.limit(@per_page, @offset)
    @names = @names.map {|n| STORE.wrap_name(n) }
  end

  def show
    @name = params[:name]
    @names = STORE.name_history(@name)
    @current = @names.last
    return render_error("Name #{@name} not found.", 404)  unless @current
    @page_title = "Name #{@name}"

    parse_output_options
    respond_with(params.keys.include?('history') ? @names : @current, @opts)
  end

  def heights
    @name = params[:name]
    records = STORE.db[:names].where(name: @name)
    return render_error("Name #{@name} not found.", 404)  unless records.any?
    txouts = STORE.db[:txout].where(id: records.map {|r| r[:txout_id] })
    txs = STORE.db[:tx].where(id: txouts.map {|o| o[:tx_id] })
    blk_txs = STORE.db[:blk_tx].where(tx_id: txs.map {|t| t[:id]})
    blocks = STORE.db[:blk].where(id: blk_txs.map {|b| b[:blk_id] }, chain: 0)
    respond_with(blocks.map {|b| { height: b[:height] } })
  end

  private

  def parse_output_options
    @opts = Hash[params.keys.grep(/^with_(.*?)$/).map {|n| [n.to_sym, true] }]
    [:block, :height, :rawtx, :mrkl_branch].each {|n|
      @opts["with_#{n}".to_sym] = true }  if params.keys.include?('with_all')
  end

end
