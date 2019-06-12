require 'kramdown'
require 'kramdown-parser-gfm'
require_relative 'rouge'
#
# Reads a given file and returns its content in various ways.
#
class BlogPostReader
  attr_reader :raw

  def initialize(file)
    @raw = parse(file)
  end

  def raw_content
    raw.last
  end

  # Read a file and split it into chunks.
  # @returns [Array] of [metadata, content]
  #
  def parse(file)
    return nil unless file.is_a?(Pathname) && file.exist?
    parts = IO.read(file, encoding: 'UTF-8').split(/^---$/, 3)
    raise StandardError unless parts.size == 3
    [YAML.safe_load(parts[1], [Date]).to_hash, parts.last]
  rescue StandardError
    LOG.error "could not parse #{file}."
    raise
  end

  def as_html
    Kramdown::Document.new(raw_content, KRAMDOWN_OPTS).to_html
  end
end
