$:.unshift( File.expand_path("../../../bitcoin-ruby/lib", __FILE__) )

require 'bitcoin'

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

Bitcoin.network = :testnet3

db_path = File.join(Rails.root, "tmp/spec.db")

# FileUtils.rm_rf db_path

import = true  unless File.exists?(db_path)
STORE = Bitcoin::Storage.sequel(db: "sqlite://#{db_path}", skip_validation: true, index_nhash: true)

datafile = File.join(Rails.root, "tmp/testnet_first500.dat")
unless File.exist?(datafile)
  require 'open-uri'
  File.open(datafile, "wb") do |file|
    file.write open("http://dumps.webbtc.com/testnet3/testnet_first500.dat").read
  end
end

STORE.import(datafile)  if import
