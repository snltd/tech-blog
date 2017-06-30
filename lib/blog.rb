#
# This is, for my own amusement, an exercise in writing a tiny,
# in-memory application for a very small website with a few dozen
# posts. This is a problem which has been solved many times, in far,
# far, better ways. Even if I were to do this myself, I should do it
# using a database, or some kind of NoSQL cache. But I'm not. I have
# a tiny Joyent SmartMachine with no spare memory, and I'm bored and
# I want to write some code. This is never, ever going to be
# scalable, highly available, or any of the things real code should
# be.
#
class Blog
  attr_reader :cache, :tags, :cd

  def initialize
    #
    # On application start, read everything in the posts/ directory
    # and build an index.  That index is a hash of posts, where the
    # key is the post filename and the value is a hash of all its
    # metadata.  The posts were written for a Jekyll site, so I am
    # going to use that same YAML front-matter.
    #
    @cd = Pathname.new(__FILE__).parent.parent.realpath + 'posts'
    @cache = generate_cache
    @tags = generate_tag_list
  end

  def generate_cache
    #
    # Generate the cache as described in the constructor
    #
    cd.children.sort.select do |f|
      f.extname == '.md' && f.file?
    end.each_with_object({}) do |f, aggr|
      content = parse_file(f)
      next unless content

      metadata = symbolize_keys(content.first)
      metadata[:link] = ['', 'post', f.basename].join('/').sub(/\.md$/, '')
      metadata[:date] = Date.strptime(metadata[:date].to_s)
      aggr[f.basename.to_s] = metadata
    end
  end

  def parse_file(file)
	  #
    # Read a file and split it into chunks. Returns an array of
    # [metadata, content]
    #
    return false unless file.is_a?(Pathname) && file.exist?
    parts = IO.read(file).split(/^---$/, 3)

    if parts.length == 3
      [YAML.load(parts[1]).to_hash, parts.last]
    else
      puts "WARNING: could not parse #{file}. Got #{parts.length} parts."
    end
  end

  def posts_by_date(year, month = '', day = '')
    #
    # search the cache and return a subset of it
    #
    pattern = [year, month, day].join('-').squeeze('-')
    cache.select { |k, v| k.start_with?(pattern) }
  end

  def posts_by_tag(tag)
    cache.select { |k, v| v[:tags].include?(tag) }
  end

  def generate_tag_list
    #
    # return an array of arrays of all tags. Sorted, descending, on
    # the number of times each tag is used
    #
    cache.map do |k, v|
      v[:tags]
    end.flatten.inject(Hash.new(0)) do |h, i|
      h[i] += 1
      h
    end.sort_by { |k, v| v }.reverse
  end

end
