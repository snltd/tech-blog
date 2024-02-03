# frozen_string_literal: true

require 'kramdown'
require 'kramdown-parser-gfm'
require_relative 'chunked_file'

module Sysdef
  #
  # render a blog post
  #
  class RenderPost
    attr_reader :chunks, :file

    # @param ident [String] of the form YYYY-mm-dd-title-of-post
    #
    def initialize(ident)
      @file = dir.join("#{ident}.md")
      @chunks = ChunkedFile.new(file)
    end

    def render
      { meta: chunks.post.metadata.merge(extra_metadata),
        content: md2html(chunks.post.body || '') }
    end

    private

    def dir
      POST_DIR
    end

    def extra_metadata
      {}
    end

    def md2html(markdown)
      Kramdown::Document.new(markdown, KRAMDOWN_OPTS).to_html
    end
  end
end
