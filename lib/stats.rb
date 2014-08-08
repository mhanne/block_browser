data = {}

def calculate_reward depth
  ((50.0 / (2 ** (depth / Bitcoin::REWARD_DROP.to_f).floor)) * 1e8).to_i
end

STORE.db.transaction do
  tx = STORE.db[:blk].where(chain: 0).join(:blk_tx, blk_id: :id)
  data = {
    blocks: {
      total: STORE.db[:blk].count,
      main: STORE.db[:blk].where(chain: 0).count,
      side: STORE.db[:blk].where(chain: 1).count,
      orphan: STORE.db[:blk].where(chain: 2).count,
      size: STORE.db[:blk].where(chain: 0).map {|b| b[:blk_size] }.inject(:+),
    },
    txs: tx.count,
    txins: tx.join(:txin, tx_id: :tx_id).count,
    txouts: tx.join(:txout, tx_id: :tx_id).count,
    addrs: STORE.db[:addr].count,
    coins: (total = 0; (STORE.get_depth + 1).times {|i| total += calculate_reward(i + 1) }; total),
    script_types: {},
    p2sh_types: {},
  }

  STORE.class::SCRIPT_TYPES.each.with_index do |type, idx|
    data[:script_types][type] = STORE.db[:txout].where(type: idx).count
    if BB_CONFIG["index_p2sh_types"]
      data[:p2sh_types][type] = STORE.db[:txin].where(p2sh_type: idx).count 
    end
  end

  data[:names] = STORE.db[:names].count  if Bitcoin.namecoin?

  data[:time] = Time.now.to_i
end



puts JSON.pretty_generate(data)

File.open(File.join(Rails.root, "public/stats.json"), 'w') {|f|
  f.write JSON.pretty_generate(data) }
