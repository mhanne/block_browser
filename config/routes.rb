BlockBrowser::Application.routes.draw do

  match 'blocks' => 'blocks#index', :as => :blocks
  match 'blocks/:id' => 'blocks#show', :as => :block
  match 'transactions/:id' => 'transactions#show', :as => :transaction
  match 'scripts/:id' => 'scripts#run', :as => :script

  root :to => 'blocks#index'

end
