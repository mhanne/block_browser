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
    block_hash = block.hash
    name ||= truncate(block_hash.sub(/^0*/, ''), 24, '...')
    link_to(name, block_path(block_hash))
  end

  def transaction_link transaction, name = nil
    transaction_hash = transaction.hash
    name ||= truncate(transaction_hash, 24, '...')
    link_to(name, tx_path(transaction_hash))
  end

  def address_link address
    link_to(address, address_path(address))
  end

  def format_time time
    Time.at(time).strftime("%Y-%m-%d %H:%M")
  end

  def format_amount amount
    "%.8f" % (amount / 1e8)
  end

end
