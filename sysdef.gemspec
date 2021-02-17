# frozen_string_literal: true

require 'date'
require 'English'

# Github actions sets the RELEASE_VERSION environment variable

Gem::Specification.new do |gem|
  gem.name          = 'sysdef'
  gem.version       = ENV['RELEASE_VERSION'] || "0.0.#{Time.now.strftime('%Y%m%d')}"

  gem.summary       = 'Sysdef Ltd company website'
  gem.description   = 'Promotional material and online presence for ' \
                      'Sysdef Ltd, a UK-registered IT company'
  gem.authors       = ['Robert Fisher']
  gem.email         = 'info@sysdef.xyz'
  gem.homepage      = 'https://sysdef.xyz'
  gem.license       = 'BSD-2-Clause'

  gem.bindir        = 'bin'
  gem.executables   = %w[sysdef.rb locate_sysdef]
  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = %w[lib]

  gem.add_runtime_dependency 'kramdown', '~> 2.3'
  gem.add_runtime_dependency 'kramdown-parser-gfm', '~> 1.1.0'
  gem.add_runtime_dependency 'puma', '~> 5.0'
  gem.add_runtime_dependency 'rouge', '~> 3.26'
  gem.add_runtime_dependency 'sinatra', '~>2.1'
  gem.add_runtime_dependency 'slim', '~> 4.1'
  gem.add_runtime_dependency 'tilt', '~> 2.0', '>= 2.0.0'

  gem.add_development_dependency 'bundler', '~> 2.0'
  gem.add_development_dependency 'faraday', '~> 1.0.1'
  gem.add_development_dependency 'minitest', '~> 5.14'
  gem.add_development_dependency 'nokogiri', '~> 1.10'
  gem.add_development_dependency 'rack-test', '~> 1.1'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rubocop', '~> 1.8'
  gem.add_development_dependency 'rubocop-minitest', '~> 0.10'
  gem.add_development_dependency 'rubocop-rake', '~> 0.5'

  gem.required_ruby_version = Gem::Requirement.new('>= 2.6.2')
end
