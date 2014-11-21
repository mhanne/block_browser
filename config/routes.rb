BlockBrowser::Application.routes.draw do

  match 'upload' => 'blocks#upload'
  match 'blocks' => 'blocks#index', :as => :blocks
  match 'block/:id' => 'blocks#block', :as => :block
  match 'tx/:id' => 'blocks#tx', :as => :tx
  match 'script/:id' => 'blocks#script', :as => :script
  match 'script' => 'blocks#script'
  match 'address/:id' => 'blocks#address', :as => :address
  match 'search/:search' => 'blocks#search', :as => :search
  match 'search' => 'blocks#search', :as => :search
  match 'unconfirmed' => 'blocks#unconfirmed', :as => :unconfirmed
  match 'scripts/:type' => 'blocks#scripts', :as => :scripts
  match 'p2sh_scripts/:type' => 'blocks#p2sh_scripts', :as => :scripts
  match 'names' => 'blocks#names', :as => :names
  match 'name/*name' => 'blocks#name', :as => :name, :constraints => /.*/

  match 'relay_tx' => 'blocks#relay_tx', :as => :relay_tx

  match 'api' => 'api#index', :as => :api
  match 'api/block' => 'api#block', :as => :block_api
  match 'api/tx' => 'api#tx', :as => :tx_api
  match 'api/address' => 'api#address', :as => :address_api
  match 'api/relay' => 'api#relay', :as => :relay_api
  match 'api/stats' => 'api#stats', :as => :stats_api

  match 'graphs' => 'blocks#graphs', :as => :graphs

  match 'about' => 'blocks#about', :as => :about
  match 'stats' => 'blocks#stats', :as => :stats
  match 'source' => 'blocks#source', :as => :source
  root :to => 'blocks#index'

end
