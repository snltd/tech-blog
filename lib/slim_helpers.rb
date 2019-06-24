# frozen_string_literal: true

# These actions are taken from inside views. They save a lot of
# clumsy passing around of variables from the router.
#
module SlimHelpers
  def list_of_pages
    POST_INDEX.link_index
  end

  def list_of_articles
    ARTICLE_INDEX.list_pages
  end

  def top_tags
    POST_INDEX.top_tags
  end
end
