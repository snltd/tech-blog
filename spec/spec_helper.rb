# frozen_string_literal: true

require 'pathname'
require 'logger'
require 'date'
require 'minitest/autorun'
require_relative '../lib/sysdef'

unless defined?(ROOT)
  ROOT = Pathname.new(__dir__).parent
  POST_DIR = ROOT + 'posts'
  ARTICLE_DIR = ROOT + 'articles'
  LOG = Logger.new('/dev/null')
  KRAMDOWN_OPTS = { input: 'GFM', hard_wrap: false }.freeze
end
