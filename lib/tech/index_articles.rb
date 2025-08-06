# frozen_string_literal: true

require_relative 'index_posts'

module Tech
  #
  # Articles are pretty much the same as posts. They just don't have
  # the date in the title.  This class produces indexes of articles
  # which look the same as the ones Tech::Index produces for
  # posts.
  #
  class IndexArticles < IndexPosts
    def list_pages
      index
    end
  end
end
