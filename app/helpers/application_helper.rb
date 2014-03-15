module ApplicationHelper

  def hth(h); h.unpack("H*")[0]; end
  def htb(h); [h].pack("H*"); end

  def format_time time
    Time.at(time).strftime("%Y-%m-%d %H:%M")
  end

  def format_amount amount
    "%.8f" % ((amount || 0) / 1e8)
  end

  def calculate_reward depth
    ((50.0 / (2 ** (depth / Bitcoin::REWARD_DROP.to_f).floor)) * 1e8).to_i
  end

end
