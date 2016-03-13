class ScriptsController < ApplicationController

  # display script execution debug trace.
  # either provide a parameter :id of the form <tx_hash>:<txin_idx>, or
  # the :script_sig, :pk_script, and optionally :sig_hash parameters for your
  # custom script. when :id is given, the :sig_hash can be overridden, and when
  # no :sig_hash is given or found, signature validation will be skipped.
  def show
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
    elsif params[:script_sig] && params[:pk_script] # when no tx is given, try to get script directly from parameters
      @script_sig = Script.from_string(params[:script_sig]).raw
      @pk_script = Script.from_string(params[:pk_script]).raw
      @sig_hash = params[:sig_hash].htb  if params[:sig_hash] && !params[:sig_hash].blank?
    else
      @script_sig = Script.from_string("1 2").raw
      @pk_script = Script.from_string("OP_ADD 3 OP_EQUAL").raw
    end

    # if there is a script, execute it
    if @script_sig && @pk_script
      @script = Script.new(@script_sig, @pk_script)

      if @script.is_script_hash?
        @inner_script = Script.new(@script.inner_p2sh_script)
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
  def index
    type = STORE.class::SCRIPT_TYPES.index(params[:type].to_sym)
    @limit = BB_CONFIG["script_list_limit"] || 10
    @offset = (params[:offset] || 0).to_i
    @count = STORE.db[:txout].where(type: type).count
    @txouts = STORE.db[:txout].where(type: type).order(:id).reverse.limit(@limit, @offset)
  end

  # list inner p2sh scripts of the given :type
  # TODO: merge with #index
  def p2sh_index
    type = STORE.class::SCRIPT_TYPES.index(params[:type].to_sym)
    @limit = BB_CONFIG["script_list_limit"] || 10
    @offset = (params[:offset] || 0).to_i
    @count = STORE.db[:txin].where(p2sh_type: type).count
    @txins = STORE.db[:txin].where(p2sh_type: type).order(:id).reverse.limit(@limit, @offset)
  end

end
