#
# Methods to render templates. You can't (easily?) put these in a
# class because of Slim's scoping, so they get included at the top
# level.
#
def render_page(dir, page, metadata)
  md_file = ROOT + dir.to_s + format('%s.md', page)
  md_file.exist? ? display_page(md_file, metadata) : display_404
end

def display_404
  @breadcrumbs = nil
  @nofooter    = true
  status 404
  slim :'404'
end

def display_page(md_file, metadata_cache)
  post_key = md_file.basename.to_s
  @meta    = metadata_cache.all[post_key]
  @posts   = POSTS.all
  @tags    = POSTS.top_tags
  @content = BlogPostReader.new(md_file).as_html
  slim :post
rescue StandardError
  status 500
  slim :'500'
end
