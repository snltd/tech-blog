# frozen_string_literal: true

require 'date'
require 'English'

# Github actions sets the RELEASE_VERSION environment variable

Gem::Specification.new do |gem|
  gem.name          = 'sysdef'
  gem.version       = ENV.fetch('RELEASE_VERSION',
                                "0.0.#{Time.now.strftime('%Y%m%d')}")

  gem.summary       = 'Sysdef Ltd company website'
  gem.description   = 'Promotional material and online presence for ' \
                      'Sysdef Ltd, a UK-registered IT company'
  gem.authors       = ['Robert Fisher']
  gem.email         = 'info@sysdef.xyz'
  gem.homepage      = 'https://sysdef.xyz'
  gem.license       = 'BSD-2-Clause'

  gem.bindir        = 'bin'
  gem.executables   = %w[sysdef.rb locate_sysdef]
  gem.files         = Dir['articles/**', 'bin/**', 'sysdef.gemspec',
                          'config.ru', 'Gemfile*', 'lib/**', 'posts/*',
                          'public/**', 'views/**', 'Rakefile', 'robots.txt']

  gem.platform      = Gem::Platform::RUBY

  gem.required_ruby_version = Gem::Requirement.new('>= 3.4.0')
  gem.metadata['rubygems_mfa_required'] = 'true'
end
