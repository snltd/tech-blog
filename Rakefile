# frozen_string_literal: true

require 'pathname'
require 'rake/testtask'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'

ROOT = Pathname(__dir__)

task default: %i[rubocop test]

Rake::TestTask.new do |t|
  t.pattern = 'spec/sysdef/*_spec.rb'
  t.warning = false
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end
