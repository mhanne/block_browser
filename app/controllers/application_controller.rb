class ApplicationController < ActionController::Base

  include Bitcoin
  include Bitcoin::Blockchain

  layout 'application'

  respond_to :html, :json, :bin, :hex

  around_filter :timeout

  protect_from_forgery

  private

  def timeout
    begin
      Timeout.timeout(BB_CONFIG['timeout']) { yield }
    rescue Exception => e
      return render_error("Request took too long.")  if e.message == "execution expired"
      raise e
    end
  end

  def render_error error
    @error = error
    render template: "blocks/error"
  end

  def tx_data_from_id tx_id
    tx = STORE.tx_by_id(tx_id)
    blk = STORE.db[:blk_tx].where(tx_id: tx.id).join(:blk, id: :blk_id).where(chain: 0).first
    return nil  unless blk
    tx_data(tx, blk)
  end

  def tx_data tx, blk
    data = tx.to_hash(with_nid: true, with_address: true, with_next_in: true)
    data['block'] = blk[:hash].hth
    data['blocknumber'] = blk[:height]
    data['time'] = Time.at(blk[:time]).utc.strftime("%Y-%m-%d %H:%M:%S")
    data
  end

end
