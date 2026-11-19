#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/tech/render_article'

unless defined?(POST_INDEX)
  POST_INDEX = Tech::IndexPosts.new(POST_DIR)
  ARTICLE_INDEX = Tech::IndexArticles.new(ARTICLE_DIR)
end

# Tests for article rendering
#
class TechRenderArticleTest < Minitest::Test
  def test_render
    r = Tech::RenderArticle.new('wavefront-cli').render
    assert_instance_of(Hash, r)
    assert_instance_of(String, r[:content])
    assert_instance_of(Hash, r[:meta])
  end
end
