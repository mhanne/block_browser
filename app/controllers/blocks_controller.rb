require 'timeout'
require 'method_source'

class BlocksController < ApplicationController

  respond_to :html, :json, :bin, :hex

  around_filter :timeout

  layout 'application'

  def index
    @per_page = 20
    STORE.instance_eval { @head = nil }
    height = STORE.height
    height = params[:height].to_i  if params[:height] && params[:height].to_i < height
    height = (@per_page - 1)  if height < @per_page
    @blocks = STORE.db[:blk].filter("height <= ?", height).where(chain: 0).order(:height).limit(@per_page).reverse
    @page_title = "Recent Blocks"
  end

  def mempool
    @per_page = 25
    @page = (params[:page] || 1).to_i
    @total = MEMPOOL.transactions.count

    filter = MEMPOOL.transactions
    filter = filter.where(type: Bitcoin::Blockchain::Mempool::TYPES.index(params[:type].to_sym))  if params[:type] && params[:type].to_sym != :all

    @txs = filter.order(:id).reverse
      .limit(@per_page).offset((@page - 1) * @per_page)
      .map {|data| Bitcoin::Blockchain::Mempool::MempoolTx.new(STORE, MEMPOOL.db, data) }
    @page_title = "Mempool (#{params[:type]})"
  end

  def block
    @block = STORE.block(params[:id])
    return render_error("Block #{params[:id]} not found.")  unless @block
    @siblings = STORE.db[:blk].where(height: @block.height).map {|b| STORE.block(b[:hash].hth) }
    @siblings.delete(@block)
    @page_title = "Block Details"
    respond_with(@block, with_next_block: true, with_nid: true, with_address: true, with_next_in: true)
  end

  def tx
    @tx = STORE.tx(params[:id])
    return render_error("Tx #{params[:id]} not found.")  unless @tx
    @blk = STORE.db[:blk][id: @tx.blk_id, chain: 0]
    @blk ||= STORE.db[:blk][id: STORE.db[:blk_tx][tx_id: @tx.id][:blk_id]]
    @page_title = "Transaction Details"
    respond_with(@tx, with_nid: true, with_address: true, with_next_in: true)
  end

  def mempool_tx
    return redirect_to tx_path(params[:id])  if STORE.has_tx(params[:id])
    @tx = MEMPOOL.get params[:id]
    return render_error("Tx #{params[:id]} not found.")  unless @tx
    @prev_outs = @tx.in.map {|i| hash = i.prev_out.reverse.hth
      (STORE.get_tx(hash) || MEMPOOL.get(hash)).out[i.prev_out_index] rescue nil }
    return render_error("Tx #{params[:id]} not found.")  unless @tx
    @page_title = "Mempool Transaction (#{@tx.type})"
    respond_with(@tx, with_nid: true)
  end

  def address
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

  # display script execution debug trace.
  # either provide a parameter :id of the form <tx_hash>:<txin_idx>, or
  # the :script_sig, :pk_script, and optionally :sig_hash parameters for your
  # custom script. when :id is given, the :sig_hash can be overridden, and when
  # no :sig_hash is given or found, signature validation will be skipped.
  def script
    @options = {
      verify_dersig: true,
      verify_low_s: true,
      verify_strictenc: true,
      verify_sigpushonly: true,
      verify_minimaldata: true,
      verify_cleanstack: true }
    @options.keys.each {|k| @options[k] = params[k] == "1"  if params[k] }

    # if tx_hash:idx is given, fetch tx from db and use those scripts
    if params[:id] =~ /([0-9a-fA-F]{64}):(\d+)/
      tx_hash, txin_idx = params[:id].split(":")
      @tx = STORE.tx(tx_hash)
      @txin = @tx.in[txin_idx.to_i]
      @txout = @txin.get_prev_out
      @script_sig = @txin.script_sig
      @pk_script = @txout.pk_script
      @sig_hash = nil
    else # when no tx is given, try to get script directly from parameters
      @script_sig = Bitcoin::Script.from_string(params[:script_sig]).raw  if params[:script_sig]
      @pk_script = Bitcoin::Script.from_string(params[:pk_script]).raw  if params[:script_sig]
      @sig_hash = params[:sig_hash].htb  if params[:sig_hash] && !params[:sig_hash].blank?
    end

    # if there is a script, execute it
    if @script_sig && @pk_script
      @script = Bitcoin::Script.new(@script_sig, @pk_script)

      if @script.is_script_hash?
        @inner_script = Bitcoin::Script.new(@script.inner_p2sh_script)
      end

      if @options[:verify_sigpushonly] && !@script.is_push_only?(@script_sig)
        return (@result, @debug = false, [[], :verify_sigpushonly])
      end

      if @options[:verify_minimaldata] && !@script.pushes_are_canonical?
        return (@result, @debug = false, [[], :verify_minimaldata])
      end

      @result = @script.run(Time.now.to_i, @options) do |pubkey, sig, hash_type, subscript|
        # get sig_hash from tx if tx is given and sig_hash isn't already set
        @sig_hash ||= @tx.signature_hash_for_input(@txin.tx_idx, subscript, hash_type)  if @tx && @txin
        # if there is a sig_hash (either computed or passed as parameter), verify signature,
        # else assume it's valid.
        @sig_hash ? Bitcoin.verify_signature(@sig_hash, sig, pubkey.unpack("H*")[0]) : true
      end
      @debug = @script.debug

      if @options[:verify_cleanstack] && !@script.stack.empty?
        @result = false
        @debug += [@script.stack, :verify_cleanstack]
      end
    end

    @page_title = "Debug Script Execution"
  end
  caches_page :script

  # list scripts of the given :type
  def scripts
    type = STORE.class::SCRIPT_TYPES.index(params[:type].to_sym)
    @limit = BB_CONFIG["script_list_limit"] || 10
    @offset = (params[:offset] || 0).to_i
    @count = STORE.db[:txout].where(type: type).count
    @txouts = STORE.db[:txout].where(type: type).order(:id).reverse.limit(@limit, @offset)
  end

  # list inner p2sh scripts of the given :type
  def p2sh_scripts
    type = STORE.class::SCRIPT_TYPES.index(params[:type].to_sym)
    @limit = BB_CONFIG["script_list_limit"] || 10
    @offset = (params[:offset] || 0).to_i
    @count = STORE.db[:txin].where(p2sh_type: type).count
    @txins = STORE.db[:txin].where(p2sh_type: type).order(:id).reverse.limit(@limit, @offset)
  end


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
    elsif STORE.is_a?(Bitcoin::Blockchain::Backends::SequelBase)
      return  if search_block(@id)
      return  if search_tx(@id)
      return  if search_mempool_tx(@id)
      return  if search_name(@id)
    end
    render_error("Nothing matches #{@id}.")
  end

  def name
    @name = params[:name]
    @names = STORE.name_history(@name)
    @current = @names.last
    return render_error("Name #{@name} not found.")  unless @current
    @page_title = "Name #{@name}"
    respond_with(params[:history] ? @names : @current)
  end

  def names
    @per_page = 20
    @page = (params[:page] || 1).to_i
    @offset = @per_page * (@page - 1)
    @max = STORE.db[:names].count
    @names = STORE.db[:names].order(:txout_id).reverse.limit(@per_page, @offset)
    @names = @names.map {|n| STORE.wrap_name(n) }
  end

  def relay_tx
    if request.post? && @input = params[:tx]
      begin
        if @input =~ /^[0-9a-f]+$/i
          @tx = Bitcoin::P::Tx.new(@input.htb)
        elsif !!JSON.parse(@input)
          @tx = Bitcoin::P::Tx.from_json(@input)
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

  def source
    git_rev = `git rev-parse --verify HEAD`.strip
    public_name = "block_browser-#{git_rev[0..8]}"
    tar_file = File.join(Rails.root, "public/#{public_name}.tar.bz2")
    unless File.exist?(tar_file)
      tmpdir = Dir.mktmpdir
      Dir.mkdir(File.join(tmpdir, public_name))
      `git clone . #{tmpdir}/#{public_name}`
      Dir.chdir(File.join(tmpdir, public_name)) { `git checkout #{git_rev}` }
      Dir.chdir(tmpdir) { `tar -cjf #{tar_file} #{public_name}` }
      FileUtils.rm_rf tmpdir
    end
    redirect_to "/#{public_name}.tar.bz2"
  end

  private

  def search_block(part)
    # blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    # hash = STORE.db[:blk].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    hash = STORE.db[:blk][hash: part.htb.to_sequel_blob][:hash].hth
    redirect_to block_path(hash)  if hash
  rescue
    nil
  end

  def search_tx(part)
    # blob = ("%" + [part].pack("H*") + "%").to_sequel_blob
    # hash = STORE.db[:tx].filter(:hash.like(blob)).first[:hash].unpack("H*")[0]
    tx = STORE.db[:tx][hash: part.htb.blob]
    tx ||= STORE.db[:tx][nhash: part.htb.blob]
    redirect_to tx_path(tx[:hash].hth)  if tx
  rescue
    nil
  end

  def search_mempool_tx(part)
    tx = MEMPOOL.get(part)
    redirect_to mempool_tx_path(tx.hash)  if tx
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

  def address_json(addr_data, addr_txouts)
    transactions = {}
    addr_txouts.each do |addr_txout|
      txout = STORE.db[:txout][id: addr_txout[:txout_id]]
      next  unless tx_data = tx_data_from_id(txout[:tx_id])
      addr_data[:tx_in_sz] += 1
      addr_data[:btc_in] += txout[:value]
      transactions[tx_data['hash']] = tx_data
      txin = STORE.db[:txin][prev_out: tx_data['hash'].htb.reverse.to_sequel_blob,
                             prev_out_index: txout[:tx_idx]]
      next  unless txin && tx_data = tx_data_from_id(txin[:tx_id])
      addr_data[:tx_out_sz] += 1
      addr_data[:btc_out] += txout[:value]
      transactions[tx_data['hash']] = tx_data
    end
    addr_data[:balance] = addr_data[:btc_in] - addr_data[:btc_out]
    addr_data[:tx_sz] = transactions.size
    addr_data[:transactions] = transactions
    JSON.pretty_generate(addr_data)
  end

  def tx_data_from_id tx_id
    tx = STORE.tx_by_id(tx_id)
    blk = STORE.db[:blk_tx].where(tx_id: tx.id).join(:blk, id: :blk_id).where(chain: 0).first
    return nil  unless blk

    data = tx.to_hash(with_nid: true, with_address: true, with_next_in: true)
    data['block'] = blk[:hash].hth
    data['blocknumber'] = blk[:height]
    data['time'] = Time.at(blk[:time]).strftime("%Y-%m-%d %H:%M:%S")
    data
  end

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
