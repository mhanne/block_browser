class PrettyJsonResponse
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    if headers["Content-Type"] =~ /^application\/json/ &&
       !env['action_dispatch.request.parameters'].keys.include?('raw')
      obj = JSON.parse(response.body)
      pretty_str = JSON.pretty_unparse(obj)
      response = [pretty_str]
      headers["Content-Length"] = Rack::Utils.bytesize(pretty_str).to_s
    end
    [status, headers, response]
  end
end
