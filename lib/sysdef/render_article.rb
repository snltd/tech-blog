# frozen_string_literal: true

require_relative 'render_post'

module Sysdef
  #
  # Render an article. Much like a blog post
  #
  class RenderArticle < RenderPost
    private

    def dir
      ARTICLE_DIR
    end

    def extra_metadata
      { mtime: file.mtime }
    end
  end
end
