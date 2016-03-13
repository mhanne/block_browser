BlockBrowser::Application.routes.draw do

  get 'upload' => 'blocks#upload'
  get 'blocks' => 'blocks#index', :as => :blocks
  get 'block/:id' => 'blocks#block', :as => :block
  get 'tx/:id' => 'blocks#tx', :as => :tx
  get 'script/:id' => 'blocks#script', :as => :script
  get 'script/:script_sig/:pk_script' => 'blocks#script'
  get 'script/:script_sig/:pk_script/:sig_hash' => 'blocks#script'
  get 'script' => 'blocks#script'
  get 'address/:id' => 'blocks#address', :as => :address
  get 'search/:search' => 'blocks#search'
  get 'search' => 'blocks#search', :as => :search
  get 'unconfirmed' => 'blocks#unconfirmed', :as => :unconfirmed
  get 'scripts/:type' => 'blocks#scripts', :as => :scripts
  get 'p2sh_scripts/:type' => 'blocks#p2sh_scripts', :as => :p2sh_scripts
  get 'names' => 'blocks#names', :as => :names
  get 'name/*name' => 'blocks#name', :as => :name#, :constraints => /.*/

  get 'relay_tx' => 'blocks#relay_tx', :as => :relay_tx

  get 'api' => 'api#index', :as => :api
  get 'api/block' => 'api#block', :as => :block_api
  get 'api/tx' => 'api#tx', :as => :tx_api
  get 'api/address' => 'api#address', :as => :address_api
  get 'api/relay' => 'api#relay', :as => :relay_api
  get 'api/stats' => 'api#stats', :as => :stats_api
  get 'api/schema' => 'api#schema', :as => :schema_api

  get 'graphs' => 'blocks#graphs', :as => :graphs

  get 'about' => 'blocks#about', :as => :about
  get 'stats' => 'blocks#stats', :as => :stats
  get 'source' => 'blocks#source', :as => :source
  root :to => 'blocks#index'

end
