class RackWavefront
  def initialize(app)
    @app = app
  end

  def call(env)
    @status, @headers, @body = @app.call(env)

    if env['REQUEST_PATH'].start_with?('/post/')
      point = { path:  'dev.rack.request2',
                value: 1,
                ts:    (Time.now.to_f * 1000).round,
                tags:  { site: SITE,
                         page: env['REQUEST_PATH']
                       } }
      wf.write_delta(point)
    end

    [@status, @headers, @body]
  rescue
    [@status, @headers, @body]
  end
end
