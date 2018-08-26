require 'pathname'
require 'rake/testtask'
require 'rubocop/rake_task'
require_relative 'lib/build_helpers'

ROOT = Pathname(__FILE__).dirname

task default: :test

Rake::TestTask.new do |t|
  t.pattern = 'spec/*_spec.rb'
  t.warning = false
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

desc 'build gem'
task build: :test do
  `gem build #{ROOT + 'sysdef.gemspec'}`
end

desc 'push to Gemfury'
task push: :build do
  if ENV['TRAVIS'] == 'true' && ENV['TRAVIS_BRANCH'] == 'master'
    puts 'Pushing to Gemfury'
    `curl --fail -vF package=@#{GEM} \
     https://push.fury.io/#{ENV['GEMFURY_TOKEN']}/#{ENV['GEMFURY_USER']}`
  elsif ENV['TRAVIS'] == 'true'
    puts 'Not on master so not pushing.'
  else
    abort 'Only Travis can push. You will have to upload manually.'
  end
end
