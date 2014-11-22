require 'SVG/Graph/Line'

GRAPH_DIR = File.join(Rails.root, "public/graphs")

data = {}

[
  :block_size, :total_size,
  :block_work, :total_work,
  :total_coins, :tx_per_block,
].each {|n| data[n] = [] }

puts "Collecting block data..."
total_size, total_work, total_coins = 0, 0, 0
STORE.db[<<EOS].each do |blk|
  SELECT depth, work, bits, blk_size AS size
  FROM blk WHERE chain = 0 ORDER BY depth
EOS

  data[:block_size] << [blk[:depth], blk[:size]]
  data[:total_size] << [blk[:depth], total_size += blk[:size]]

  data[:block_work] << [blk[:depth], Bitcoin.block_difficulty(blk[:bits])]
  data[:total_work] << [blk[:depth], blk[:work]]

  total_coins += Bitcoin.block_creation_reward(blk[:depth])
end

puts "Collecting tx data..."
STORE.db[<<EOS].each do |blk|
  SELECT blk.depth, count(blk_tx)
  FROM blk
  JOIN blk_tx ON blk.id = blk_tx.blk_id
  WHERE blk.chain = 0 GROUP BY blk.depth
EOS
  data[:tx_per_block] << [blk[:depth], blk[:count]]
end

total = 0; reward = 50e8;
16.times do |i|
  data[:total_coins] << [210_000*i, total/1e8]
  data[:total_coins].last << total/1e8  if i < 3
  total += 210_000 * reward
  reward /= 2
end

data.each do |name, lines|
  print "#{name} ... "

  File.open(File.join(GRAPH_DIR, "#{name}.data"), "w") do |file|
    lines.each {|l| file.write("#{l.join(" ")}\n") }
  end

  Dir.chdir(GRAPH_DIR) do
    `gnuplot -e "width=480;height=320;outfile='#{name}_small.png'" #{Rails.root}/lib/graphs/#{name}.cfg`
    `gnuplot -e "width=1024;height=800;outfile='#{name}.png'" #{Rails.root}/lib/graphs/#{name}.cfg`
    puts "[DONE]"
  end

end


