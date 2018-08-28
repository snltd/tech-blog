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
  success = system("gem build #{ROOT + 'sysdef.gemspec'}")
  abort 'could not build gem' unless success
end

desc 'push to Gemfury'
task push: :build do
  if !env?(:GEMFURY_TOKEN)
    puts 'No Gemfury token. Not pushing.'
  elsif !env?(:CI_COMMIT_TAG)
    puts 'Not tagged. Not pushing.'
  else
    puts 'Pushing to Gemfury.'
    resp = push_to_gemfury(most_recent_gem)
    p resp
    abort "Failed to push. Code #{resp.status}." unless resp.status == 200
    puts 'Successfully pushed to Gemfury.'
  end
end
