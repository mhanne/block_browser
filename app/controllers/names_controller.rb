class NamesController < ApplicationController

  def index
    @per_page = 20
    @page = (params[:page] || 1).to_i
    @offset = @per_page * (@page - 1)
    @max = STORE.db[:names].count
    @names = STORE.db[:names].order(:txout_id).reverse.limit(@per_page, @offset)
    @names = @names.map {|n| STORE.wrap_name(n) }
  end

  def show
    @name = params[:name]
    @names = STORE.name_history(@name)
    @current = @names.last
    return render_error("Name #{@name} not found.")  unless @current
    @page_title = "Name #{@name}"
    respond_with(params[:history] ? @names : @current)
  end

end
