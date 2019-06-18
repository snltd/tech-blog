# frozen_string_literal: true

require 'kramdown'
require_relative 'chunked_file'

module Sysdef
  #
  # render pages of reviews
  #
  class RenderPost
    attr_reader :chunks

    # @param ident [String] of the form YYYY-mm-dd-title-of-post
    #
    def initialize(ident)
      @chunks = ChunkedFile.new(POST_DIR + (ident + '.md'))
    end

    def render
      { meta: chunks.post.metadata,
        content: md2html(chunks.post.body || '') }
    end

    private

    def md2html(markdown)
      Kramdown::Document.new(markdown, KRAMDOWN_OPTS).to_html
    end
  end
end
