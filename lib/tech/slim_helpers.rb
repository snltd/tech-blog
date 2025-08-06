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

  def expand_years
    this_year = Date.today.year
    ret = this_year.downto(2020).to_a
    ret << @page[:meta][:date].year if @page&.dig(:meta, :date)
    ret
  end
end
