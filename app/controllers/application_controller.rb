class ApplicationController < ActionController::Base

  include Bitcoin::Storage
  
  layout 'application'

  protect_from_forgery

end
