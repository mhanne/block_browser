module ApplicationHelper

  def hth(h); h.unpack("H*")[0]; end
  def htb(h); [h].pack("H*"); end

  def format_time time
    Time.at(time).strftime("%Y-%m-%d %H:%M")
  end

  def format_amount amount
    "%.8f" % (amount / 1e8)
  end

end
