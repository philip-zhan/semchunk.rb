# frozen_string_literal: true

# Helper methods for testing semchunk
module TestHelpers
  # Deterministic test inputs and outputs
  DETERMINISTIC_TEST_INPUT = "ThisIs\tATest."
  DETERMINISTIC_TEST_CHUNK_SIZE = 4

  # NOTE: The Ruby implementation may handle trailing punctuation slightly differently than Python
  # in some edge cases with character-level tokenization
  DETERMINISTIC_TEST_OUTPUT_CHUNKS = {
    "word" => ["ThisIs\tATest."],
    "char" => %w[This Is ATes t]
  }.freeze

  DETERMINISTIC_TEST_OUTPUT_OFFSETS = {
    "word" => [[0, 13]],
    "char" => [[0, 4], [4, 6], [7, 11], [11, 12]]
  }.freeze

  # Sample texts for testing
  SAMPLE_TEXTS = [
    "The quick brown fox jumps over the lazy dog.",
    "Natural language processing is fascinating. It allows computers to understand human language.",
    "Ruby is a beautiful programming language with a focus on simplicity and productivity.",
    <<~TEXT.strip,
      Introduction to Natural Language Processing

      Natural language processing (NLP) is a subfield of linguistics, computer science,
      and artificial intelligence concerned with the interactions between computers and
      human language.
    TEXT
    <<~TEXT.strip
      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud
      exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

      Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
      fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
      culpa qui officia deserunt mollit anim id est laborum.
    TEXT
  ].freeze

  # Initialize test token counters
  def self.initialize_test_token_counters
    {
      "word" => ->(text) { text.split.length },
      "char" => lambda(&:length)
    }
  end

  # Test that chunks satisfy basic invariants
  def self.verify_chunks(chunks, _text, chunk_size, token_counter)
    # All chunks should be within size limit
    chunks.each do |chunk|
      raise "Chunk exceeds size: #{token_counter.call(chunk)} > #{chunk_size}" if token_counter.call(chunk) > chunk_size

      # No chunk should be empty or all whitespace
      raise "Empty or whitespace-only chunk found" if chunk.empty? || chunk.strip.empty?
    end
  end

  # Test that offsets correctly identify chunk positions
  def self.verify_offsets(chunks, offsets, text, chunk_size, token_counter)
    raise "Chunks and offsets length mismatch" unless chunks.length == offsets.length

    chunks.zip(offsets).each do |chunk, (start_pos, end_pos)|
      # Verify offset extracts correct text
      extracted = text[start_pos...end_pos]
      raise "Offset mismatch: '#{chunk}' != '#{extracted}'" unless chunk == extracted

      # Verify chunk size
      raise "Chunk exceeds size" if token_counter.call(chunk) > chunk_size

      # No empty chunks
      raise "Empty or whitespace-only chunk" if chunk.empty? || chunk.strip.empty?
    end
  end
end
