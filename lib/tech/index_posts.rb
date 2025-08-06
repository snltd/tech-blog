# frozen_string_literal: true

require_relative 'chunked_file'

module Tech
  #
  # Read all the posts (markdown files) in a given directory, and
  # create a hash of filename => metadata. This is done once, when
  # the application starts, so adding new pages implies a restart.
  # This is fine, as we deploy as a package.
  #
  class IndexPosts
    attr_reader :file_list, :index, :uris, :link_index

    def initialize(dir = 'posts')
      @file_list = build_file_list(dir)
      @index = build_global_index
      @link_index = build_link_index
    end

    def random_post
      index.sample[:page]
    end

    def by_tag(tag)
      index.select { |i| i[:tags].include?(tag) }.sort_by { |i| i[:date] }
           .reverse
    end

    def top_tags(limit = 10)
      all_tags.take(limit)
    end

    private

    def build_file_list(dir)
      dir.children.select { |f| f.extname == '.md' }.sort.reverse
    end

    # @return [Array[Hash]] of post metadata.
    #
    def build_global_index
      file_list.map { |f| index_entry(f) }.flatten.compact
    end

    # Read a post and extract from it the YAML metadata block.
    # from the given file
    # @return [Hash]
    # { title: 'zr, for your ZFS pleasure',
    #   date: Date.new,
    #   tags: [ZFS, Ruby],
    #   layout: post,
    #   category: ZFS }
    #
    def index_entry(file)
      enhance_metadata(file, ChunkedFile.new(file).post.metadata)
    end

    def enhance_metadata(file, meta)
      raise unless metadata_okay?(meta)

      meta.tap do |m|
        m[:page] = fname_to_link(file)
        m[:file] = file
        m[:mtime] = file.mtime
      end
    end

    def metadata_okay?(meta)
      meta && (required_keys - meta.keys).empty?
    end

    # The structure used to build the collapsible index down the
    # right hand side of the page.
    #
    # @return [Hash] key is a year, value is a hash where the key is
    #   a link and the value is the title of the post
    #
    def build_link_index
      index.each_with_object({}) do |entry, a|
        index_entry_to_link_index_entry(entry, a)
      end
    end

    # @param entry [Hash] description of a page from @index
    # @param aggr [Hash] link index so far
    # @return [Hash] aggr with entry added
    #
    def index_entry_to_link_index_entry(entry, aggr)
      year = entry[:date].year
      aggr[year] ||= {}
      datelink, display = menu_item(entry)

      return aggr[year][datelink] = display unless aggr[year].key?(datelink)

      aggr[year][datelink][:artists] << entry[:artist]
    end

    def menu_item(entry)
      [format('/post/%<link>s', link: fname_to_link(entry[:file])),
       { title: entry[:title], date: entry[:date] }]
    end

    def fname_to_link(fname)
      fname.basename.to_s.chomp('.md')
    end

    def required_keys
      %i[title date tags]
    end

    def all_tags
      tags = index.map { |i| i[:tags] }.flatten
      counted_tags = tags.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }
      counted_tags.sort_by { |_k, v| v }.reverse
    end
  end
end
