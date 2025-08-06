#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/tech/chunked_file'

# Chunked reader tests. These tests use real files from the live
# site.
#
class TechChunkedFileTest < MiniTest::Test
  def test_chunks
    tu = Tech::ChunkedFile.new(POST_DIR.join('2019-04-04-zr.md'))
    assert_instance_of(Array, tu.chunks)
    assert_equal(1, tu.chunks.size)
  end

  def test_missing_file
    assert_raises(Sinatra::NotFound) do
      Tech::ChunkedFile.new(POST_DIR.join('2019-04-04-missing.md'))
    end
  end
end
