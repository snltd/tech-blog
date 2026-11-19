#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'

# Tests for the article indexer
#
class TechIndexArticlesTest < Minitest::Test
  attr_reader :tu

  def setup
    @tu = Tech::IndexArticles.new(ARTICLE_DIR).index
  end

  def test_index
    assert_instance_of(Array, tu)
    refute_empty(tu)
    tu.each { |i| assert_instance_of(Hash, i) }
  end

  def test_index_entry
    idx = tu.select { |i| i[:title] == 'A New Wavefront CLI' }

    assert_instance_of(Array, idx)
    assert_equal(1, idx.size)

    article = idx[0]

    assert_instance_of(Hash, article)

    assert_equal('A New Wavefront CLI', article[:title])
    assert_equal(%w[Wavefront Ruby], article[:tags])
    assert_instance_of(Date, article[:date])
    assert_equal(ARTICLE_DIR.join('wavefront-cli.md'), article[:file])
    assert_equal('wavefront-cli', article[:page])
  end
end
