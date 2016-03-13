class AddressController < ApplicationController

  def show
    @address = params[:id]
    unless Bitcoin.valid_address?(@address)
      return render_error("Address #{params[:id]} is invalid.")
    end
    @hash160 = Bitcoin.hash160_from_address(@address)
    @type = Bitcoin.address_type(@address)

    @addr_data = { address: @address, hash160: @hash160,
                   tx_in_sz: 0, tx_out_sz: 0, btc_in: 0, btc_out: 0 }

    @addr_txouts = STORE.db[:addr].where(hash160: @hash160)
                   .where("addr.type = #{STORE.class::ADDRESS_TYPES.index(@type)}")
                   .join(:addr_txout, addr_id: :id).join(:txout, id: :txout_id)
                   .join(:tx, id: :tx_id).join(:blk_tx, tx_id: :id).join(:blk, id: :blk_id)
                   .where(chain: 0).order(:height)

    if @addr_txouts.count > (BB_CONFIG['max_addr_txouts'] || 100)
      return render_error("Too many outputs for this address (#{@addr_txouts.count})")
    end

    respond_to do |format|
      format.html do
        @page_title = "Address #{@address}"
        @tx_list = render_to_string partial: "address_tx"
      end
      format.json { render text: address_json(@addr_data, @addr_txouts) }
    end
  end

  private
  
  def address_json(addr_data, addr_txouts)
    unspent, transactions = [], {}
    addr_txouts.each do |addr_txout|
      txout = STORE.db[:txout][id: addr_txout[:txout_id]]
      next  unless txout_tx_data = tx_data_from_id(txout[:tx_id])
      addr_data[:tx_in_sz] += 1
      addr_data[:btc_in] += txout[:value]
      transactions[txout_tx_data['hash']] = txout_tx_data
      txin = STORE.db[:txin][prev_out: txout_tx_data['hash'].htb.reverse.to_sequel_blob,
                             prev_out_index: txout[:tx_idx]]
      if txin && txin_tx_data = tx_data_from_id(txin[:tx_id])
        addr_data[:tx_out_sz] += 1
        addr_data[:btc_out] += txout[:value]
        transactions[txin_tx_data['hash']] = txin_tx_data
      else
        unspent << { tx: { hash: txout_tx_data['hash'], n: txout[:tx_idx] }}
                  .merge(txout_tx_data['out'][txout[:tx_idx]])
      end
    end
    addr_data[:balance] = addr_data[:btc_in] - addr_data[:btc_out]
    addr_data[:unspent] = unspent
    addr_data[:tx_sz] = transactions.size
    addr_data[:transactions] = transactions
    JSON.pretty_generate(addr_data)
  end

end
