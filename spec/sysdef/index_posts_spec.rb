#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/sysdef/index_posts'

# Tests
#
class SysdefIndexPostsTest < MiniTest::Test
  attr_reader :tu

  def setup
    @tu = Sysdef::IndexPosts.new(POST_DIR)
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

    out.each do |p|
      assert_instance_of(Hash, p)
      assert_equal([], %i[title date file] - p.keys)
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
    assert_instance_of(Hash, out[0])
    assert_equal(
      { title: 'Why I Hate DevOps',
        date: Date.new(2015, 5, 5),
        tags: ['DevOps', 'Rant', 'professional suicide'],
        category: 'articles',
        page: '2015-05-05-why-i-hate-devops',
        file: Pathname.new(POST_DIR + '2015-05-05-why-i-hate-devops.md'),
    }, out[0]
    )
  end

  def test_link_index
    out = tu.link_index
    assert_instance_of(Hash, out)

    out.each_pair do |year, data|
      assert_instance_of(Integer, year)
      assert year.between?(2004, Date.today.year)
      assert_instance_of(Hash, data)

      data.each_pair do |link, title|
        assert_instance_of(String, link)
        assert link.start_with?('/date/2')
        assert_instance_of(String, title)
      end
    end
  end
end
