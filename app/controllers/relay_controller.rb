class RelayController < ApplicationController

  def relay_tx
    if request.post? && @input = params[:tx]
      begin
        if @input =~ /^[0-9a-f]+$/i
          @tx = P::Tx.new(@input.htb)
        elsif !!JSON.parse(@input)
          @tx = P::Tx.from_json(@input)
        end
      rescue
        @error = "Error decoding transaction."
      end

      unless @error
        if (tx = STORE.db[:tx][hash: @tx.hash.htb.to_sequel_blob]) &&
          STORE.db[:blk_tx].where(tx_id: tx[:id]).join(:blk, id: :blk_id).where(chain: 0).any?
          @error = "Transaction is already confirmed."
        end
      end

      unless @error
        @wait = (params[:wait] || BB_CONFIG['relay_wait_default']).to_f
        @wait = BB_CONFIG['relay_wait_max']  if @wait > BB_CONFIG['relay_wait_max']

        @result = node_command(:relay_tx, hex: @tx.to_payload.hth,
                                          send: BB_CONFIG['relay_send'], wait: @wait)
        @error, @details = @result["error"], @result["details"]  if @result["error"]
      end
    end
    respond_to do |format|
      format.json do
        if @error
          res = { error: @error }
          res[:details] = @details  if @details
          render(text: JSON.pretty_generate(res), status: :unprocessable_entity)
        else
          render(text: JSON.pretty_generate(@result))
        end
      end
      format.html
    end
  rescue Exception => ex
    p $!; puts *$@
    respond_to do |format|
      format.json { render(json: { error: $!.message }, status: :internal_server_error) }
      format.html { @error = $! }
    end
  end

  private

  def node_command cmd, params
    s = TCPSocket.new(*BB_CONFIG["command"].split(":"))
    s.write({id: 1, method: "relay_tx", params: params}.to_json + "\x00")
    buf = ""
    while b = s.read(1)
      break  if b == "\x00"
      buf << b
    end
    JSON.parse(buf)["result"]
  end

end
