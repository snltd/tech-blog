#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/tech/render_post'

unless defined?(POST_INDEX)
  POST_INDEX = Tech::IndexPosts.new(POST_DIR)
  ARTICLE_INDEX = Tech::IndexArticles.new(ARTICLE_DIR)
end

# Tests for blog post rendering
#
class TechRenderPostTest < MiniTest::Test
  def test_render
    r = Tech::RenderPost.new('2015-05-05-why-i-hate-devops').render
    assert_instance_of(Hash, r)
    assert_instance_of(String, r[:content])
    assert_instance_of(Hash, r[:meta])
  end
end
