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
  SELECT height, work, bits, blk_size AS size
  FROM blk WHERE chain = 0 ORDER BY height
EOS

  data[:block_size] << [blk[:height], blk[:size]]
  data[:total_size] << [blk[:height], total_size += blk[:size]]

  data[:block_work] << [blk[:height], Bitcoin.block_difficulty(blk[:bits])]
  data[:total_work] << [blk[:height], blk[:work]]

  total_coins += Bitcoin.block_creation_reward(blk[:height])
end

puts "Collecting tx data..."
STORE.db[<<EOS].each do |blk|
  SELECT blk.height, count(blk_tx)
  FROM blk
  JOIN blk_tx ON blk.id = blk_tx.blk_id
  WHERE blk.chain = 0 GROUP BY blk.height
EOS
  data[:tx_per_block] << [blk[:height], blk[:count]]
end

height = STORE.height
total = 0; reward = 50e8;
160.times do |i|
  data[:total_coins] << [21_000*i, total/1e8]
  data[:total_coins].last << total/1e8  if i < height / 21_000
  total += 21_000 * reward
  reward /= 2  if i > 0 && (i+1) % 10 == 0
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


