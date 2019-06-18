#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/sysdef/render_post'

unless defined?(POST_INDEX)
  POST_INDEX = Sysdef::IndexPosts.new(POST_DIR)
  ARTICLE_INDEX = Sysdef::IndexArticles.new(ARTICLE_DIR)
end

# Tests for blog post rendering
#
class SysdefRenderPostTest < MiniTest::Test
  def test_render
    r = Sysdef::RenderPost.new('2015-05-05-why-i-hate-devops').render
    assert_instance_of(Hash, r)
    assert_instance_of(String, r[:content])
    assert_instance_of(Hash, r[:meta])
  end
end
