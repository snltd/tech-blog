# frozen_string_literal: true

require_relative 'render_post'

module Sysdef
  #
  # render draft articles
  #
  class RenderDraft < RenderPost
    private

    def dir
      DRAFT_DIR
    end

    def extra_metadata
      { mtime: Time.now }
    end
  end
end
