class RackWavefront
  def initialize(app)
    @app = app
  end

  def call(env)
    @status, @headers, @body = @app.call(env)

    if env['REQUEST_PATH'].start_with?('/post/')
      WF.write_delta(path: 'rack.request', value: 1,
                     tags: { site: SITE, page: env['REQUEST_PATH'] })
    end

    [@status, @headers, @body]
  rescue
    [@status, @headers, @body]
  end
end
