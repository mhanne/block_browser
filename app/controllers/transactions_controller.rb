class TransactionsController < ApplicationController

  def show
    @transaction = Transaction.get(params[:id])
    @page_title = "Transaction Details"
  end

end
