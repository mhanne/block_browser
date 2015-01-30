class ApplicationController < ActionController::Base

  include Bitcoin::Blockchain

  layout 'application'

  protect_from_forgery

end
