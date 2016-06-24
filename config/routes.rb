BlockBrowser::Application.routes.draw do

  get 'upload' => 'blocks#upload'
  get 'blocks' => 'blocks#index', as: :blocks
  get 'block/:id' => 'blocks#show', as: :block
  get 'tx/:id' => 'tx#show', as: :tx
  get 'script/:id' => 'scripts#show', as: :script
  get 'script/:script_sig/:pk_script' => 'scripts#show'
  get 'script/:script_sig/:pk_script/:sig_hash' => 'scripts#show'
  get 'script' => 'scripts#show'
  get 'address/:id/unspent' => 'address#unspent', as: :address_unspent
  get 'address/:id' => 'address#show', as: :address
  get 'search/:search' => 'search#search'
  get 'search' => 'search#search', as: :search
  get 'unconfirmed' => 'blocks#unconfirmed', as: :unconfirmed
  get 'scripts/:type' => 'scripts#index', as: :scripts
  get 'p2sh_scripts/:type' => 'scripts#p2sh_index', as: :p2sh_scripts
  get 'names' => 'names#index', as: :names
  get 'name/heights/*name' => 'names#heights', as: :name_heights
  get 'name/*name' => 'names#show', as: :name

  get 'relay_tx' => 'relay#relay_tx'
  post 'relay_tx' => 'relay#relay_tx'

  get 'api' => 'api#index', as: :api
  get 'api/block' => 'api#block', as: :block_api
  get 'api/tx' => 'api#tx', as: :tx_api
  get 'api/address' => 'api#address', as: :address_api
  get 'api/name' => 'api#name', as: :name_api
  get 'api/relay' => 'api#relay', as: :relay_api
  get 'api/stats' => 'api#stats', as: :stats_api
  get 'api/schema' => 'api#schema', as: :schema_api

  get 'graphs' => 'blocks#graphs', as: :graphs

  get 'about' => 'blocks#about', as: :about
  get 'stats' => 'stats#stats', as: :stats
  get 'source' => 'source#source', as: :source
  root :to => 'blocks#index'

end
