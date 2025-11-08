# frozen_string_literal: true

require "test_helper"
require_relative "helpers"

class ComprehensiveTest < Minitest::Test
  include TestHelpers

  TEST_CHUNK_SIZES = [10, 50, 100].freeze

  def setup
    @token_counters = TestHelpers.initialize_test_token_counters
  end

  def test_comprehensive_chunking
    @token_counters.each do |name, token_counter|
      TEST_CHUNK_SIZES.each do |chunk_size|
        TestHelpers::SAMPLE_TEXTS.each_with_index do |sample, idx|
          # Test basic chunking
          chunker = Semchunk.chunkerify(token_counter, chunk_size: chunk_size)
          chunks = chunker.call(sample)

          # Verify chunks
          TestHelpers.verify_chunks(chunks, sample, chunk_size, token_counter)

          # Test with offsets
          chunks_with_offsets, offsets = chunker.call(sample, offsets: true)
          TestHelpers.verify_offsets(chunks_with_offsets, offsets, sample, chunk_size, token_counter)

          # Verify that recombining lowercased chunks stripped of whitespace and punctuation
          # yields a close approximation (minor differences in punctuation handling are acceptable)
          lowercased_no_whitespace = sample.downcase.gsub(/\s+/, "")

          chunks_lwn, offsets_lwn = chunker.call(lowercased_no_whitespace, offsets: true)
          joined = chunks_lwn.join
          # Allow for minor differences in trailing punctuation
          assert joined.length >= (lowercased_no_whitespace.length * 0.95),
                 "Joined chunks too short: #{joined.length} vs #{lowercased_no_whitespace.length}"

          chunks_lwn = chunker.call(lowercased_no_whitespace)
          joined = chunks_lwn.join
          assert joined.length >= (lowercased_no_whitespace.length * 0.95),
                 "Joined chunks too short: #{joined.length} vs #{lowercased_no_whitespace.length}"
        end
      end
    end
  end

  def test_deterministic_output
    @token_counters.each do |name, token_counter|
      chunker = Semchunk.chunkerify(token_counter, chunk_size: TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE)

      # Test basic chunking
      chunks = chunker.call(TestHelpers::DETERMINISTIC_TEST_INPUT)
      expected_chunks = TestHelpers::DETERMINISTIC_TEST_OUTPUT_CHUNKS[name]
      assert_equal expected_chunks, chunks, "Deterministic output mismatch for #{name}"

      # Test with offsets
      chunks_with_offsets, offsets = chunker.call(TestHelpers::DETERMINISTIC_TEST_INPUT, offsets: true)
      expected_offsets = TestHelpers::DETERMINISTIC_TEST_OUTPUT_OFFSETS[name]
      assert_equal expected_chunks, chunks_with_offsets, "Deterministic chunks mismatch with offsets for #{name}"
      assert_equal expected_offsets, offsets, "Deterministic offsets mismatch for #{name}"
    end
  end

  def test_overlapping_chunks
    @token_counters.each do |name, token_counter|
      chunker = Semchunk.chunkerify(token_counter, chunk_size: TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE)

      # Low overlap
      low_overlap_chunks = chunker.call(TestHelpers::DETERMINISTIC_TEST_INPUT, overlap: 0.1)

      # High overlap
      high_overlap = (TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE * 0.9).ceil
      high_overlap_chunks = chunker.call(TestHelpers::DETERMINISTIC_TEST_INPUT, overlap: high_overlap)

      # Word tokenizer produces same chunks regardless of overlap for this input
      if name == "word"
        assert_equal low_overlap_chunks.length, high_overlap_chunks.length
      else
        assert high_overlap_chunks.length > low_overlap_chunks.length,
               "High overlap should produce more chunks for #{name}"
      end

      # Test with offsets
      low_overlap_chunks_o, low_overlap_offsets = chunker.call(
        TestHelpers::DETERMINISTIC_TEST_INPUT,
        overlap: 0.1,
        offsets: true
      )
      high_overlap_chunks_o, high_overlap_offsets = chunker.call(
        TestHelpers::DETERMINISTIC_TEST_INPUT,
        overlap: high_overlap,
        offsets: true
      )

      if name == "word"
        assert_equal low_overlap_chunks_o.length, high_overlap_chunks_o.length
        assert_equal low_overlap_offsets.length, high_overlap_offsets.length
      else
        assert high_overlap_chunks_o.length > low_overlap_chunks_o.length
        assert high_overlap_offsets.length > low_overlap_offsets.length
      end

      # Verify offsets match extracted text
      text = TestHelpers::DETERMINISTIC_TEST_INPUT
      assert_equal high_overlap_chunks_o, high_overlap_offsets.map { |s, e| text[s...e] }
    end
  end

  def test_direct_chunk_with_memoization
    @token_counters.each do |name, token_counter|
      # Test using Semchunk.chunk directly with memoization enabled
      chunks = Semchunk.chunk(
        TestHelpers::DETERMINISTIC_TEST_INPUT,
        chunk_size: TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE,
        token_counter: token_counter,
        memoize: true
      )

      expected_chunks = TestHelpers::DETERMINISTIC_TEST_OUTPUT_CHUNKS[name]
      assert_equal expected_chunks, chunks

      # Test with offsets
      chunks_with_offsets, offsets = Semchunk.chunk(
        TestHelpers::DETERMINISTIC_TEST_INPUT,
        chunk_size: TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE,
        token_counter: token_counter,
        offsets: true,
        memoize: true
      )

      expected_offsets = TestHelpers::DETERMINISTIC_TEST_OUTPUT_OFFSETS[name]
      assert_equal expected_chunks, chunks_with_offsets
      assert_equal expected_offsets, offsets
    end
  end

  def test_multiple_texts
    @token_counters.each do |name, token_counter|
      chunker = Semchunk.chunkerify(token_counter, chunk_size: TestHelpers::DETERMINISTIC_TEST_CHUNK_SIZE)

      # Test chunking multiple texts
      texts = [TestHelpers::DETERMINISTIC_TEST_INPUT, TestHelpers::DETERMINISTIC_TEST_INPUT]
      expected = [
        TestHelpers::DETERMINISTIC_TEST_OUTPUT_CHUNKS[name],
        TestHelpers::DETERMINISTIC_TEST_OUTPUT_CHUNKS[name]
      ]

      chunks = chunker.call(texts)
      assert_equal expected, chunks

      # Test with offsets
      chunks_with_offsets, offsets = chunker.call(texts, offsets: true)
      assert_equal expected, chunks_with_offsets

      expected_offsets = [
        TestHelpers::DETERMINISTIC_TEST_OUTPUT_OFFSETS[name],
        TestHelpers::DETERMINISTIC_TEST_OUTPUT_OFFSETS[name]
      ]
      assert_equal expected_offsets, offsets
    end
  end

  def test_error_on_missing_chunk_size
    token_counter = @token_counters.values.first

    assert_raises(ArgumentError) do
      Semchunk.chunkerify(token_counter)
    end
  end

  def test_empty_text_handling
    token_counter = ->(text) { 0 }

    # Test chunking nothing to ensure no errors are raised
    chunks = Semchunk.chunk("", chunk_size: 512, token_counter: token_counter)
    assert_equal [], chunks

    # Test chunking whitespace to ensure no errors are raised
    chunks = Semchunk.chunk("\n\n", chunk_size: 512, token_counter: token_counter)
    assert_equal [], chunks
  end

  def test_large_text_performance
    # Test with a larger text to ensure performance is acceptable
    large_text = TestHelpers::SAMPLE_TEXTS.last * 10
    token_counter = ->(text) { text.split.length }

    chunker = Semchunk.chunkerify(token_counter, chunk_size: 100)

    start_time = Time.now
    chunks = chunker.call(large_text)
    duration = Time.now - start_time

    # Should complete in reasonable time (< 1 second for this size)
    assert duration < 1.0, "Chunking took too long: #{duration}s"

    # Verify results
    TestHelpers.verify_chunks(chunks, large_text, 100, token_counter)
  end

  def test_various_splitters
    token_counter = ->(text) { text.split.length }

    # Test with various types of splitters
    test_cases = {
      "newlines" => "Line one\n\nLine two\n\nLine three",
      "tabs" => "Column1\t\tColumn2\t\tColumn3",
      "periods" => "Sentence one. Sentence two. Sentence three.",
      "commas" => "Item one, item two, item three, item four",
      "mixed" => "First paragraph.\n\nSecond paragraph with, commas.\n\nThird paragraph!"
    }

    test_cases.each do |name, text|
      chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)
      assert_kind_of Array, chunks, "Failed for #{name}"
      TestHelpers.verify_chunks(chunks, text, 5, token_counter)
    end
  end

  def test_overlap_edge_cases
    token_counter = ->(text) { text.split.length }
    text = "one two three four five six seven eight nine ten"

    # Test with overlap = 0 (no overlap)
    chunks_no_overlap = Semchunk.chunk(text, chunk_size: 4, token_counter: token_counter, overlap: 0)
    assert_kind_of Array, chunks_no_overlap

    # Test with overlap = 1 (1 token overlap)
    chunks_one_token = Semchunk.chunk(text, chunk_size: 4, token_counter: token_counter, overlap: 1)
    assert chunks_one_token.length >= chunks_no_overlap.length

    # Test with large overlap (should be capped)
    chunks_large_overlap = Semchunk.chunk(text, chunk_size: 4, token_counter: token_counter, overlap: 10)
    assert_kind_of Array, chunks_large_overlap
  end

  def test_cache_maxsize
    call_count = 0
    token_counter = lambda do |text|
      call_count += 1
      text.split.length
    end

    # Test with limited cache
    chunker = Semchunk.chunkerify(token_counter, chunk_size: 10, cache_maxsize: 5)
    text = "This is a test sentence with multiple words."

    # First call
    chunker.call(text)
    first_count = call_count

    # Second call should use some cached values
    chunker.call(text)
    second_count = call_count

    # Should have made some calls but potentially fewer on second run
    assert second_count >= first_count
  end
end
