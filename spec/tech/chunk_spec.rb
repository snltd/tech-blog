#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/tech/chunk'

SAMPLE_POST = %(
---
title: "zr, for your ZFS pleasure"
date: 2019-04-04
tags: [ZFS, Ruby]
layout: post
category: ZFS
---

Here is the content.
)

SAMPLE_FILE = Pathname.new('/test/file')

# Tests for Chunks
#
class TechChunkTest < Minitest::Test
  attr_reader :tu

  def setup
    @tu = Tech::Chunk.new(SAMPLE_FILE, SAMPLE_POST)
  end

  def test_raw
    assert_equal(SAMPLE_POST, tu.raw)
  end

  def test_metadata
    assert_equal(
      { title: 'zr, for your ZFS pleasure',
        date: Date.new(2019, 4, 4),
        tags: %w[ZFS Ruby],
        layout: 'post',
        category: 'ZFS' }, tu.metadata
    )
  end

  def test_body
    assert_instance_of(String, tu.body)
    assert_equal('Here is the content.', tu.body)
  end
end
