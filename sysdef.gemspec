# frozen_string_literal: true

require 'date'
require 'English'

Gem::Specification.new do |gem|
  gem.name          = 'sysdef'
  gem.version       = '0.0.0'
  gem.date          = Date.today.to_s

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

  gem.add_runtime_dependency 'kramdown', '~> 2.1.0'
  gem.add_runtime_dependency 'kramdown-parser-gfm', '~> 1.1.0'
  gem.add_runtime_dependency 'puma', '~> 3.12'
  gem.add_runtime_dependency 'rouge', '~> 3.3'
  gem.add_runtime_dependency 'sinatra', '~>2.0'
  gem.add_runtime_dependency 'slim', '~> 4.0'
  gem.add_runtime_dependency 'tilt', '~> 2.0', '>= 2.0.0'

  gem.add_development_dependency 'bundler', '~> 2.0'
  gem.add_development_dependency 'faraday', '~> 0.15.0'
  gem.add_development_dependency 'minitest', '~> 5.11'
  gem.add_development_dependency 'nokogiri', '~> 1.10'
  gem.add_development_dependency 'rack-test', '~> 1.1'
  gem.add_development_dependency 'rake', '~> 12.3'
  gem.add_development_dependency 'rubocop', '~> 0.71'

  gem.required_ruby_version = Gem::Requirement.new('>= 2.6.0')
end
