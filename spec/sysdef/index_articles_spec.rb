#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/cassingle/index_articles'

# Tests for the article indexer
#
class CassingleIndexArticlesTest < MiniTest::Test
  attr_reader :tu

  def setup
    @tu = Cassingle::IndexArticles.new(ARTICLE_DIR).index
  end

  def test_index
    assert_instance_of(Array, tu)
    refute_empty(tu)
    tu.each { |i| assert_instance_of(Hash, i) }
  end

  def test_index_entry
    idx = tu.select { |i| i[:title] == 'Christmas Spacker' }

    assert_instance_of(Array, idx)
    assert_equal(1, idx.size)
    assert_instance_of(Hash, idx[0])
    assert_equal(
      { title: 'Christmas Spacker',
        link: '/article/christmas_spacker',
        page: 'christmas_spacker',
        file: ARTICLE_DIR + 'christmas_spacker.md',
        date: Date.new(2018, 12, 25) }, idx[0]
    )
  end
end
