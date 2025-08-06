# frozen_string_literal: true

require 'logger'
require 'minitest/autorun'
require_relative '../lib/tech'

unless defined?(ROOT)
  ROOT = Pathname.new(__dir__).parent
  POST_DIR = ROOT.join('posts')
  ARTICLE_DIR = ROOT.join('articles')
  LOG = Logger.new(File::NULL)
  KRAMDOWN_OPTS = { input: 'GFM', hard_wrap: false }.freeze
end
