#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/sysdef/render_article'

unless defined?(POST_INDEX)
  POST_INDEX = Sysdef::IndexPosts.new(POST_DIR)
  ARTICLE_INDEX = Sysdef::IndexArticles.new(ARTICLE_DIR)
end

# Tests for article rendering
#
class SysdefRenderArticleTest < MiniTest::Test
  def test_render
    r = Sysdef::RenderArticle.new('wavefront-cli').render
    assert_instance_of(Hash, r)
    assert_instance_of(String, r[:content])
    assert_instance_of(Hash, r[:meta])
  end
end
