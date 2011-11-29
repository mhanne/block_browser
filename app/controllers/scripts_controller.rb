class ScriptsController < ApplicationController
  
  def run
    @input = Input.find(params[:id])
    @output = @input.previous_output
    @script = Bitcoin::Script.new(@input.script + @output.script)
    @debug = []
    @result = @script.run(@debug) { true }
    @page_title = "Script Details"
  end

end
