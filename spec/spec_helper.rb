# setup bundler

require 'bundler'
Bundler.setup


# setup bitcoin-ruby

require 'bitcoin/blockchain'
require 'bitcoin/node'
require 'bitcoin/wallet'
require 'bitcoin/namecoin'

Bitcoin.network = :namecoin


# setup coverage report

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::HTMLFormatter])

SimpleCov.start do
  add_filter "/config/"
end


# setup rails environment

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'


# rspec configuration
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|

  # Enable old `should` syntax
  config.expect_with(:rspec) { |c| c.syntax = :should }

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

# The settings below are suggested to provide a good initial experience
# with RSpec, but feel free to customize to your heart's content.
=begin
  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  config.disable_monkey_patching!

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed
=end
end


# setup test DB

db_path = File.join(Rails.root, "tmp/spec.db")
FileUtils.mkdir_p File.dirname(db_path)
# FileUtils.rm_rf db_path

Bitcoin.network = :namecoin
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


# set command socket for tests

BB_CONFIG["command"] = "localhost:22034"

# copy a dummy stats.json file to be used in tests
unless File.exists?("public/stats.json")
  `cp spec/data/stats.json public/`
end


# fake blockchain to be used in tests
# TODO: move into separate gem

class FakeChain

  include Bitcoin::Builder

  GENESIS = Bitcoin::P::Block.new("010000000000000000000000000000000000000000000000000000000000000000000000bbed8b03a246434da28c883e5c36860984cdbc9501e6751b6441dd5f0574aa3514b5d152f8ff071f533600000101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff101ef6a77b8ec0a2aee3040628bef836c7ffffffff0100f2052a010000001976a91454bd602f3df3315c80a04326bd193a583a1d353988ac00000000".htb)

  attr_accessor :key, :store

  def initialize key, storage, command = nil
    @key, @store, @command = key, storage, command
    Bitcoin.network[:genesis_hash] = GENESIS.hash
    @store.new_block GENESIS
    @prev_hash = @store.head.hash
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
  @store.height.should == 123
  `cp spec/data/base.db spec/tmp/testbox1.db`
end


# run bitcoin nodes for testing

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
  Bitcoin.network = :namecoin
end
