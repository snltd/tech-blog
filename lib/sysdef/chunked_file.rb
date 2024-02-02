# frozen_string_literal: true

require 'sinatra/base'
require_relative 'chunk'

module Sysdef
  #
  # Split a post file into chunks. Each chunk is an object of type
  # Sysdef::Chunk.
  #
  class ChunkedFile
    attr_reader :file, :chunks

    # @param file [Pathname] the file we want to break into chunks
    #
    def initialize(file)
      @file = file
      @chunks = parse
    end

    def post
      chunks.first
    end

    private

    def parse
      File.read(file, encoding: 'UTF-8').split(/^---$/, 2).map(&:strip)
          .reject(&:empty?).map { |str| Sysdef::Chunk.new(file, str) }
    rescue StandardError
      LOG.error format('cannot read file %<file>s', file:)
      raise Sinatra::NotFound
    end
  end
end
