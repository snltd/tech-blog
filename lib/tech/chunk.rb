# frozen_string_literal: true

module Tech
  #
  # Tech::ChunkedFile breaks a file down into "chunks". Each chunk
  # has some YAML metadata, and a body. This class creates and
  # manipulates them.
  #
  class Chunk
    attr_reader :file, :raw, :metadata

    def initialize(file, str, mdata: false)
      @file = file
      @raw = str
      @metadata = mdata || extract_metadata
    end

    def body
      raw.split("\n\n", 2).last.strip
    end

    private

    # @param chunk [String] a review, including YAML metadata
    # @return [Hash] review metadata, ready to add to the index
    #
    def extract_metadata
      metadata, = split_off_metadata
      YAML.safe_load(metadata, permitted_classes: [Date],
                               symbolize_names: true)
    rescue RuntimeError => e
      puts e
      LOG.warn format("%<fname>s: could not parse '%<mdata>s'",
                      fname: file.basename,
                      mdata: metadata.gsub("\n", '\n'))
      {}
    end

    def split_off_metadata
      raw.split("\n\n", 2)
    end
  end
end
