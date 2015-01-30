$:.unshift( File.expand_path("../../../bitcoin-ruby/lib", __FILE__) )

require 'bundler'
Bundler.setup

require 'bitcoin/blockchain'
require 'bitcoin/node'
require 'bitcoin/wallet'
require 'bitcoin/namecoin'

Bitcoin.network = :namecoin

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::HTMLFormatter]

SimpleCov.start do
  add_filter "/config/"
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
#Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"
end

Bitcoin.network = :namecoin

db_path = File.join(Rails.root, "tmp/spec.db")
FileUtils.mkdir_p File.dirname(db_path)
# FileUtils.rm_rf db_path

import = true  unless File.exists?(db_path)
STORE = Bitcoin::Blockchain.create_store(:archive, db: "sqlite://#{db_path}",
  skip_validation: true, index_nhash: true, index_p2sh_type: true)

datafile = File.join(Rails.root, "tmp/namecoin_first500.dat")
unless File.exist?(datafile)
  require 'open-uri'
  File.open(datafile, "wb") do |file|
    file.write open("http://dumps.webbtc.com/namecoin/namecoin_first500.dat").read
  end
end

`rm #{ENV["HOME"]}/.bitcoin-ruby/namecoin/import_resume.state`
STORE.import(datafile)  if import

BB_CONFIG["command"] = "localhost:22034"

unless File.exists?("public/stats.json")
  `cp spec/data/stats.json public/`
end


class FakeChain

  include Bitcoin::Builder

  GENESIS = Bitcoin::P::Block.new("010000000000000000000000000000000000000000000000000000000000000000000000bbed8b03a246434da28c883e5c36860984cdbc9501e6751b6441dd5f0574aa3514b5d152f8ff071f533600000101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff101ef6a77b8ec0a2aee3040628bef836c7ffffffff0100f2052a010000001976a91454bd602f3df3315c80a04326bd193a583a1d353988ac00000000".htb)

  attr_accessor :key, :store

  def initialize key, storage, command = nil
    @key, @store, @command = key, storage, command
    Bitcoin.network[:genesis_hash] = GENESIS.hash
    @store.new_block GENESIS
    @prev_hash = @store.get_head.hash
    @tx = []
  end

  def add_tx tx, conf = 0
    @tx << tx
    conf.times { new_block }
  end

  def new_block
    blk = build_block(Bitcoin.decode_compact_bits(Bitcoin.network[:proof_of_work_limit])) do |b|
      b.prev_block @prev_hash
      b.tx do |t|
        t.input {|i| i.coinbase }
        t.output do |o|
          o.value 5000000000
          o.script do |s|
            s.type :address
            s.recipient @key.addr
          end
        end
      end

      @tx.uniq(&:hash).each {|tx| b.tx tx }
      @tx = []
    end

    @prev_hash = blk.hash
    send_block(blk)
  end

  def send_block blk
    if @command
      EM.run do
        Bitcoin::Node::CommandClient.connect(*@command) do
          on_connected { request(:store_block, hex: blk.payload.hth) }
          on_response { EM.stop }
        end
      end
    end
    @store.new_block(blk)
  end   

end

def setup_fake_chain
  @key = Bitcoin::Key.from_base58("92Pt1VX7sBoW37svE1X3mHUGjkYMbfj1D7fy2nTh8fezot3KdLp")
  rebuild = !File.exist?("spec/data/base.db")
  @store = Bitcoin::Blockchain.create_store(:archive, db: "sqlite://spec/data/base.db",
    index_nhash: true, log_level: :warn)
  @fake_chain = FakeChain.new(@key, @store)
  if rebuild
    puts "Creating fake chain..."
    123.times { print "\rGenerated block #{@fake_chain.new_block[0]}/#{123}"; sleep 0.2 }
  end
  @store.get_depth.should == 123
  `cp spec/data/base.db spec/tmp/testbox1.db`
end

def run_bitcoin_node
  Bitcoin.network = :regtest
  Bitcoin.network[:genesis_hash] = "00006c62931caa8550b8a3be9364126126ef2b193facbac421ee21b9680a7d97"
  `rm -rf spec/tmp`; `mkdir -p spec/tmp`
  setup_fake_chain

  options = Bitcoin::Config.load_file({}, "spec/data/node1.conf", :blockchain)
  options[:log] = { network: :warn, storage: :warn }
  @node1_pid = fork do
    node = Bitcoin::Node::Node.new(options)
    node.log.level = :warn
    node.run
  end
  sleep 1
end

def kill_bitcoin_node
  Process.kill("KILL", @node1_pid) rescue nil
  `rm -rf spec/tmp`
end
