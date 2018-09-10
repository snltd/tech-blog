require_relative 'common'
require_relative 'blog_post_reader'

# Read all the posts (markdown files) in a given directory, and
# create a hash of filename => metadata. This is done once, when the
# application starts, so adding new pages implies a restart. This is
# fine, as we deploy as a package.
#
class BlogPosts
  attr_reader :all, :dir, :uris

  def initialize(dir = 'posts')
    @dir  = dir
    @all  = generate_cache
    @uris = uri_list
  end

  def generate_cache
    all_files.each_with_object({}) do |f, a|
      page = BlogPostReader.new(f).raw
      a[f.basename.to_s] = extract_metadata(f, page.first) if page
    end
  end

  def extract_metadata(file, metadata)
    md = symbolize_keys(metadata)
    md[:link] = ['', 'post', file.basename].join('/').sub(/\.md$/, '')
    md[:date] = Date.strptime(md[:date].to_s)
    md
  end

  def post_dir
    Pathname.new(__FILE__).dirname.parent.realpath + dir
  end

  def all_files
    post_dir.children.select { |f| f.extname == '.md' && f.file? }.sort
  end

  def by_tag(tag)
    all.select { |_k, v| v[:tags].include?(tag) }
  end

  def by_date(year, month = '', day = '')
    pattern = [year, month, day].join('-').squeeze('-')
    all.select { |k, _v| k.start_with?(pattern) }
  end

  def all_tags
    tags = all.map { |_k, v| v[:tags] }.flatten
    counts = tags.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }
    counts.sort_by { |_k, v| v }.reverse
  end

  def top_tags(limit = 10)
    all_tags.take(limit)
  end

  # For the health check, we render a randomly chosen page. This
  # method returns a list of all available page URIs
  #
  def uri_list
    all.keys.map { |p| p.chomp('.md') }
  end
end
