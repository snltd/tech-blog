# frozen_string_literal: true

def gem_version
  if env?(:CIRCLE_TAG)
    ENV['CIRCLE_TAG']
  elsif env?(:CIRCLE_BUILD_NUM)
    "0.0.0-#{ENV['CIRCLE_BUILD_NUM']}"
  else
    '0.0.0'
  end
end

def most_recent_gem
  Pathname.glob("#{ROOT}/pkg/*.gem").max
end

def env?(var)
  ENV.key?(var.to_s) && !ENV[var.to_s].empty?
end

# Upload the given file to Gemfury.
# @param file [Pathname,String] gemfile to upload
# @return Faraday::Response
#
def push_to_gemfury(file)
  gemfury_connection.post(
    '/sysdef/',
    payload: Faraday::UploadIO.new(file.to_s,
                                   'application/x-www-form-urlencoded')
  )
end

# @return [Faraday] a connection to Gemfury.
#
def gemfury_connection
  require 'faraday' # include at the top, and the build will fail

  Faraday.new(url: 'https://push.fury.io') do |f|
    f.basic_auth(ENV['GEMFURY_TOKEN'], nil)
    f.request(:multipart)
    f.request(:url_encoded)
    f.adapter(Faraday.default_adapter)
  end
end
