class TxController < ApplicationController

  def show
    @tx = STORE.tx(params[:id])
    return render_error("Tx #{params[:id]} not found.")  unless @tx
    @blk = STORE.db[:blk][id: @tx.blk_id, chain: 0]
    @blk ||= STORE.db[:blk][id: STORE.db[:blk_tx][tx_id: @tx.id][:blk_id]]

    respond_to do |format|
      format.html do
        @page_title = "Transaction Details"
      end
      format.json { render text: JSON.pretty_generate(tx_data(@tx, @blk)) }
      format.hex { render text: @tx.to_payload.hth }
      format.bin { render text: @tx.to_payload }
    end
  end

end
