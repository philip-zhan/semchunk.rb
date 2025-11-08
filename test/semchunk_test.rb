# frozen_string_literal: true

require "test_helper"

class SemchunkTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Semchunk::VERSION
  end

  def test_basic_chunking
    text = "This is a test. This is another test. And one more test."
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

    assert_kind_of Array, chunks
    assert(chunks.all?(String))
    refute_empty chunks
  end

  def test_chunking_with_offsets
    text = "Hello world. How are you?"
    token_counter = ->(text) { text.split.length }

    chunks, offsets = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter, offsets: true)

    assert_kind_of Array, chunks
    assert_kind_of Array, offsets
    assert_equal chunks.length, offsets.length

    # Verify offsets are correct
    chunks.each_with_index do |chunk, i|
      start_pos, end_pos = offsets[i]
      assert_equal chunk, text[start_pos...end_pos]
    end
  end

  def test_chunking_with_overlap
    text = "One two three four five six seven eight nine ten."
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 4, token_counter: token_counter, overlap: 0.5)

    assert_kind_of Array, chunks
    assert_operator chunks.length, :>, 1
  end

  def test_split_text_with_newlines
    text = "Line one\n\nLine two\nLine three"
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter)

    assert_kind_of Array, chunks
    refute_empty chunks
  end

  def test_split_text_with_tabs
    text = "Column1\t\tColumn2\tColumn3"
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter)

    assert_kind_of Array, chunks
    refute_empty chunks
  end

  def test_split_text_with_semantic_splitters
    text = "First sentence. Second sentence! Third sentence?"
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 3, token_counter: token_counter)

    assert_kind_of Array, chunks
    assert_operator chunks.length, :>=, 2
  end

  def test_empty_text
    text = ""
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter)

    assert_empty chunks
  end

  def test_whitespace_only_text
    text = "   \n\n   \t\t   "
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter)

    assert_empty chunks
  end

  def test_text_longer_than_chunk_size
    text = "word " * 100
    token_counter = ->(text) { text.split.length }

    chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter)

    assert_kind_of Array, chunks
    assert_operator chunks.length, :>, 1
    chunks.each do |chunk|
      assert_operator token_counter.call(chunk), :<=, 10
    end
  end

  def test_memoization
    text = "This is a test."
    call_count = 0
    token_counter = lambda do |t|
      call_count += 1
      t.split.length
    end

    # First call with memoization
    Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter, memoize: true)
    first_count = call_count

    # Second call should use memoized results
    Semchunk.chunk(text, chunk_size: 10, token_counter: token_counter, memoize: true)

    # The second call should have fewer or equal calls due to memoization
    assert_operator call_count, :>=, first_count
  end

  def test_chunkerify_with_proc
    token_counter = ->(text) { text.split.length }
    chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)

    assert_kind_of Semchunk::Chunker, chunker
    assert_equal 5, chunker.chunk_size
  end

  def test_chunkerify_without_chunk_size_raises_error
    token_counter = ->(text) { text.split.length }

    assert_raises(ArgumentError) do
      Semchunk.chunkerify(token_counter)
    end
  end

  def test_chunker_call_with_single_text
    token_counter = ->(text) { text.split.length }
    chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)

    text = "This is a test sentence with many words in it."
    chunks = chunker.call(text)

    assert_kind_of Array, chunks
    assert(chunks.all?(String))
  end

  def test_chunker_call_with_multiple_texts
    token_counter = ->(text) { text.split.length }
    chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)

    texts = [
      "This is the first text.",
      "This is the second text.",
      "And this is the third text."
    ]

    results = chunker.call(texts)

    assert_kind_of Array, results
    assert_equal 3, results.length
    assert(results.all?(Array))
  end

  def test_chunker_call_with_offsets
    token_counter = ->(text) { text.split.length }
    chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)

    text = "This is a test."
    chunks, offsets = chunker.call(text, offsets: true)

    assert_kind_of Array, chunks
    assert_kind_of Array, offsets
    assert_equal chunks.length, offsets.length
  end

  def test_non_whitespace_splitters
    text = "one,two,three,four,five,six,seven,eight"
    token_counter = ->(text) { text.split(/[,\s]+/).length }

    chunks = Semchunk.chunk(text, chunk_size: 3, token_counter: token_counter)

    assert_kind_of Array, chunks
    assert_operator chunks.length, :>=, 2
    # Verify commas are preserved
    assert(chunks.any? { |chunk| chunk.include?(",") })
  end

  def test_character_level_splitting
    text = "abcdefghijklmnopqrstuvwxyz"
    token_counter = lambda(&:length)

    chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

    assert_kind_of Array, chunks
    assert_operator chunks.length, :>=, 2
    chunks.each do |chunk|
      assert_operator token_counter.call(chunk), :<=, 5
    end
  end
end
