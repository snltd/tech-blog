#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/tech/index_posts'

# Tests
#
class TechIndexPostsTest < Minitest::Test
  attr_reader :tu

  def setup
    @tu = Tech::IndexPosts.new(POST_DIR)
  end

  def test_file_list
    out = tu.file_list
    assert_instance_of(Array, out)
    assert_equal(out, out.sort.reverse)

    out.each do |f|
      assert_instance_of(Pathname, f)
      assert_equal('.md', f.extname)
      assert_equal(POST_DIR, f.dirname)
    end
  end

  def test_index
    out = tu.index
    assert_instance_of(Array, out)
    expected_keys = %i[title date file]

    out.each do |p|
      assert_instance_of(Hash, p)
      assert_empty(expected_keys - p.keys)
    end
  end

  def test_random_post
    assert_match(/^\d{4}-\d{2}-\d{2}-[\w-]+$/, tu.random_post)
  end

  # #index_entry is now a private method, so we'll pull something
  # "known" out of the real index and test that.
  #
  def test_index_entry
    out = tu.index.select { |i| i[:title] == 'Why I Hate DevOps' }
    assert_instance_of(Array, out)
    assert_equal(1, out.size)
    post = out.first
    assert_instance_of(Hash, post)
    assert_equal('Why I Hate DevOps', post[:title])
    assert_equal(Date.new(2015, 5, 5), post[:date])
    assert_equal(['DevOps', 'Rant', 'professional suicide'], post[:tags])
    assert_equal('articles', post[:category])
    assert_equal('2015-05-05-why-i-hate-devops', post[:page])
    assert_equal(POST_DIR.join('2015-05-05-why-i-hate-devops.md'), post[:file])
    assert_instance_of(Time, post[:mtime])
  end

  def test_link_index
    out = tu.link_index
    assert_instance_of(Hash, out)

    out.each_pair do |year, data|
      assert_instance_of(Integer, year)
      assert year.between?(2004, Date.today.year)
      assert_instance_of(Hash, data)

      data.each_pair do |link, meta|
        assert_instance_of(String, link)
        assert link.start_with?('/post/2')
        assert_instance_of(Hash, meta)
        assert_instance_of(String, meta[:title])
        assert_instance_of(Date, meta[:date])
      end
    end
  end
end
