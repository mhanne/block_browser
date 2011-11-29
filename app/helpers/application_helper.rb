module ApplicationHelper

  def hth(h); h.unpack("H*")[0]; end
  def htb(h); [h].pack("H*"); end

  def truncate(str, len, omission)
    if str.size > len
      str[0...len] + omission
    else
      str
    end
  end

  def block_link block, name = nil
    block_hash = hth(block.block_hash)
    name ||= truncate(block_hash.sub(/^0*/, ''), 24, '...')
    link_to(name, block_path(block_hash))
  end

  def transaction_link transaction, name = nil
    transaction_hash = hth(transaction.transaction_hash)
    name ||= truncate(transaction_hash, 24, '...')
    link_to(name, transaction_path(transaction_hash))
  end

  def format_time time
    time.strftime("%Y-%m-%d %H:%M")
  end

end
