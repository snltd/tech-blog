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
  p ENV
  `gem build #{ROOT + 'sysdef.gemspec'}`
end

desc 'push to Gemfury'
task push: :build do
  abort 'No Gemfury credentials.' unless ENV['GEMFURY_TOKEN']

  puts 'Pushing to Gemfury'
  `curl --fail -vF package=@#{GEM} \
   https://push.fury.io/#{ENV['GEMFURY_TOKEN']}/sysdef`
end
