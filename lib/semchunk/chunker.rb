# frozen_string_literal: true

require "set"

module Semchunk
  # A class for chunking one or more texts into semantically meaningful chunks
  class Chunker
    attr_reader :chunk_size, :token_counter

    def initialize(chunk_size:, token_counter:)
      @chunk_size = chunk_size
      @token_counter = token_counter
    end

    # Split text or texts into semantically meaningful chunks
    #
    # @param text_or_texts [String, Array<String>] The text or texts to be chunked
    # @param processes [Integer] The number of processes to use when chunking multiple texts (not yet implemented)
    # @param progress [Boolean] Whether to display a progress bar when chunking multiple texts (not yet implemented)
    # @param offsets [Boolean] Whether to return the start and end offsets of each chunk
    # @param overlap [Float, Integer, nil] The proportion of the chunk size, or, if >=1, the number of tokens, by which chunks should overlap
    #
    # @return [Array<String>, Array<Array>, Hash] Depending on the input and options, returns chunks and optionally offsets
    def call(text_or_texts, processes: 1, progress: false, offsets: false, overlap: nil)
      chunk_function = make_chunk_function(offsets: offsets, overlap: overlap)

      # Handle single text
      if text_or_texts.is_a?(String)
        return chunk_function.call(text_or_texts)
      end

      # Handle multiple texts
      if processes == 1
        # TODO: Add progress bar support
        chunks_and_offsets = text_or_texts.map { |text| chunk_function.call(text) }
      else
        # TODO: Add parallel processing support
        raise NotImplementedError, "Parallel processing not yet implemented. Please use processes: 1"
      end

      # Return results
      if offsets
        chunks, offsets_arr = chunks_and_offsets.transpose
        return [chunks.to_a, offsets_arr.to_a]
      end

      chunks_and_offsets
    end

    private

    def make_chunk_function(offsets:, overlap:)
      lambda do |text|
        Semchunk.chunk(
          text,
          chunk_size: chunk_size,
          token_counter: token_counter,
          memoize: false,
          offsets: offsets,
          overlap: overlap
        )
      end
    end
  end
end
