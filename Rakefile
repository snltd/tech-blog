# frozen_string_literal: true

require 'pathname'
require 'rake/testtask'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require_relative 'lib/build_helpers'

ROOT = Pathname(__dir__)

task default: %i[rubocop test]

Rake::TestTask.new do |t|
  t.pattern = 'spec/sysdef/*_spec.rb'
  t.warning = false
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

desc 'push to Gemfury'
task push: :build do
  if !env?(:GEMFURY_TOKEN)
    puts 'No Gemfury token. Not pushing.'
  elsif !env?(:CIRCLE_TAG)
    puts 'Not tagged. Not pushing.'
  else
    puts 'Pushing to Gemfury.'
    resp = push_to_gemfury(most_recent_gem)
    abort "Failed to push. Code #{resp.status}." unless resp.status == 200
    puts 'Successfully pushed to Gemfury.'
  end
end
