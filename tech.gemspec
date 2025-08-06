# frozen_string_literal: true

# Github actions sets the RELEASE_VERSION environment variable

Gem::Specification.new do |gem|
  gem.name          = 'tech-blog'
  gem.version       = ENV.fetch('RELEASE_VERSION',
                                "0.0.#{Time.now.strftime('%Y%m%d')}")

  gem.summary       = 'Nerdy scribblings'
  gem.description   = 'Nerdy scribblings on obscure tech'
  gem.authors       = ['Robert Fisher']
  gem.email         = 'services@id264.net'
  gem.homepage      = 'https://tech.id264.net'
  gem.license       = 'BSD-2-Clause'

  gem.bindir        = 'bin'
  gem.executables   = %w[tech.rb]
  gem.files         = Dir['articles/**', 'bin/**', 'tech.gemspec',
                          'config.ru', 'Gemfile*', 'lib/**', 'posts/*',
                          'public/**', 'views/**', 'Rakefile', 'robots.txt']

  gem.platform      = Gem::Platform::RUBY

  gem.required_ruby_version = Gem::Requirement.new('>= 3.4.0')
  gem.metadata['rubygems_mfa_required'] = 'true'
end
