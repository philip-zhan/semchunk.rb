# frozen_string_literal: true

require_relative "semchunk/version"
require_relative "semchunk/chunker"

module Semchunk
  # A map of token counters to their memoized versions
  @memoized_token_counters = {}

  class << self
    attr_reader :memoized_token_counters

    # Split a text into semantically meaningful chunks of a specified size as determined by the provided token counter.
    #
    # @param text [String] The text to be chunked.
    # @param chunk_size [Integer] The maximum number of tokens a chunk may contain.
    # @param token_counter [Proc, Method, #call] A callable that takes a string and returns the number of tokens in it.
    # @param memoize [Boolean] Whether to memoize the token counter. Defaults to true.
    # @param offsets [Boolean] Whether to return the start and end offsets of each chunk. Defaults to false.
    # @param overlap [Float, Integer, nil] The proportion of the chunk size, or, if >=1, the number of tokens, by which chunks should overlap. Defaults to nil.
    # @param cache_maxsize [Integer, nil] The maximum number of text-token count pairs that can be stored in the token counter's cache. Defaults to nil (unbounded).
    # @param recursion_depth [Integer] Internal parameter for tracking recursion depth.
    # @param start [Integer] Internal parameter for tracking character offset.
    #
    # @return [Array<String>, Array<Array>] A list of chunks up to chunk_size-tokens-long, with any whitespace used to split the text removed, and, if offsets is true, a list of tuples [start, end].
    def chunk(text, chunk_size:, token_counter:, memoize: true, offsets: false, overlap: nil, cache_maxsize: nil,
              recursion_depth: 0, start: 0)
      return_offsets = offsets
      is_first_call = recursion_depth.zero?

      # Initialize token counter and compute effective chunk size
      token_counter, local_chunk_size, overlap, unoverlapped_chunk_size = initialize_chunking_params(
        token_counter, chunk_size, overlap, is_first_call, memoize, cache_maxsize
      )

      # Split text and prepare metadata
      splitter, splitter_is_whitespace, splits = split_text(text)
      split_starts, cum_lens, num_splits_plus_one = prepare_split_metadata(splits, splitter, start)

      # Process splits into chunks
      chunks, offsets_arr = process_splits(
        splits,
        split_starts,
        cum_lens,
        splitter,
        splitter_is_whitespace,
        token_counter,
        local_chunk_size,
        num_splits_plus_one,
        recursion_depth
      )

      # Finalize first call: cleanup and overlap
      finalize_chunks(
        chunks,
        offsets_arr,
        is_first_call,
        return_offsets,
        overlap,
        local_chunk_size,
        chunk_size,
        unoverlapped_chunk_size,
        text
      )
    end

    # A tuple of semantically meaningful non-whitespace splitters
    NON_WHITESPACE_SEMANTIC_SPLITTERS = [
      # Sentence terminators
      ".",
      "?",
      "!",
      "*",
      # Clause separators
      ";",
      ",",
      "(",
      ")",
      "[",
      "]",
      ", ",
      "'",
      "'",
      "'",
      '"',
      "`",
      # Sentence interrupters
      ":",
      "—",
      "…",
      # Word joiners
      "/",
      "\\",
      "–",
      "&",
      "-"
    ].freeze

    private

    def initialize_chunking_params(token_counter, chunk_size, overlap, is_first_call, memoize, cache_maxsize)
      local_chunk_size = chunk_size
      unoverlapped_chunk_size = nil

      return [token_counter, local_chunk_size, overlap, unoverlapped_chunk_size] unless is_first_call

      token_counter = memoize_token_counter(token_counter, cache_maxsize) if memoize

      if overlap
        overlap = compute_overlap(overlap, chunk_size)

        if overlap.positive?
          unoverlapped_chunk_size = chunk_size - overlap
          local_chunk_size = [overlap, unoverlapped_chunk_size].min
        end
      end

      [token_counter, local_chunk_size, overlap, unoverlapped_chunk_size]
    end

    def compute_overlap(overlap, chunk_size)
      if overlap < 1
        (chunk_size * overlap).floor
      else
        [overlap, chunk_size - 1].min
      end
    end

    def prepare_split_metadata(splits, splitter, start)
      splitter_len = splitter.length
      split_lens = splits.map(&:length)

      cum_lens = [0]
      split_lens.each { |len| cum_lens << (cum_lens.last + len) }

      split_starts = [0]
      split_lens.each_with_index do |split_len, i|
        split_starts << (split_starts[i] + split_len + splitter_len)
      end
      split_starts = split_starts.map { |s| s + start }

      num_splits_plus_one = splits.length + 1

      [split_starts, cum_lens, num_splits_plus_one]
    end

    def process_splits(splits, split_starts, cum_lens, splitter, splitter_is_whitespace,
                       token_counter, local_chunk_size, num_splits_plus_one, recursion_depth)
      chunks = []
      offsets_arr = []
      skips = Set.new
      splitter_len = splitter.length

      splits.each_with_index do |split, i|
        next if skips.include?(i)

        split_start = split_starts[i]

        if token_counter.call(split) > local_chunk_size
          new_chunks, new_offsets = chunk_recursively(split, local_chunk_size, token_counter, recursion_depth, split_start)
          chunks.concat(new_chunks)
          offsets_arr.concat(new_offsets)
        else
          final_split_i, new_chunk = merge_splits(
            splits:        splits,
            cum_lens:      cum_lens,
            chunk_size:    local_chunk_size,
            splitter:      splitter,
            token_counter: token_counter,
            start:         i,
            high:          num_splits_plus_one
          )

          ((i + 1)...final_split_i).each { |j| skips.add(j) }
          chunks << new_chunk
          split_end = split_starts[final_split_i] - splitter_len
          offsets_arr << [split_start, split_end]
        end

        append_splitter_if_needed(
          chunks,
          offsets_arr,
          splitter,
          splitter_is_whitespace,
          i,
          splits,
          skips,
          token_counter,
          local_chunk_size,
          split_start,
          splitter_len
        )
      end

      [chunks, offsets_arr]
    end

    def chunk_recursively(split, local_chunk_size, token_counter, recursion_depth, split_start)
      chunk(
        split,
        chunk_size: local_chunk_size,
        token_counter: token_counter,
        offsets: true,
        recursion_depth: recursion_depth + 1,
        start: split_start
      )
    end

    def append_splitter_if_needed(chunks, offsets_arr, splitter, splitter_is_whitespace,
                                  i, splits, skips, token_counter, local_chunk_size,
                                  split_start, splitter_len)
      return if splitter_is_whitespace
      return if i == splits.length - 1
      return if ((i + 1)...splits.length).all? { |j| skips.include?(j) }

      last_chunk_with_splitter = chunks[-1] + splitter
      if token_counter.call(last_chunk_with_splitter) <= local_chunk_size
        chunks[-1] = last_chunk_with_splitter
        offset_start, offset_end = offsets_arr[-1]
        offsets_arr[-1] = [offset_start, offset_end + splitter_len]
      else
        offset_start = offsets_arr.empty? ? split_start : offsets_arr[-1][1]
        chunks << splitter
        offsets_arr << [offset_start, offset_start + splitter_len]
      end
    end

    def finalize_chunks(chunks, offsets_arr, is_first_call, return_offsets, overlap,
                        local_chunk_size, chunk_size, unoverlapped_chunk_size, text)
      return [chunks, offsets_arr] unless is_first_call

      chunks, offsets_arr = remove_empty_chunks(chunks, offsets_arr)

      if overlap&.positive? && chunks.any?
        chunks, offsets_arr = apply_overlap(
          chunks,
          offsets_arr,
          local_chunk_size,
          chunk_size,
          unoverlapped_chunk_size,
          text
        )
      end

      return [chunks, offsets_arr] if return_offsets

      chunks
    end

    def remove_empty_chunks(chunks, offsets_arr)
      chunks_and_offsets = chunks.zip(offsets_arr).reject { |chunk, _| chunk.empty? || chunk.strip.empty? }

      if chunks_and_offsets.any?
        chunks_and_offsets.transpose
      else
        [[], []]
      end
    end

    def apply_overlap(chunks, offsets_arr, subchunk_size, chunk_size, unoverlapped_chunk_size, text)
      subchunks = chunks
      suboffsets = offsets_arr
      num_subchunks = subchunks.length

      subchunks_per_chunk = (chunk_size.to_f / subchunk_size).floor
      subchunk_stride = (unoverlapped_chunk_size.to_f / subchunk_size).floor

      num_overlapping_chunks = [1, ((num_subchunks - subchunks_per_chunk).to_f / subchunk_stride).ceil + 1].max

      offsets_arr = (0...num_overlapping_chunks).map do |i|
        start_idx = i * subchunk_stride
        end_idx = [start_idx + subchunks_per_chunk, num_subchunks].min - 1
        [suboffsets[start_idx][0], suboffsets[end_idx][1]]
      end

      chunks = offsets_arr.map { |s, e| text[s...e] }

      [chunks, offsets_arr]
    end

    public

    # Construct a chunker that splits one or more texts into semantically meaningful chunks
    #
    # @param tokenizer_or_token_counter [String, #encode, Proc, Method, #call] Either: the name of a tokenizer; a tokenizer that possesses an encode method; or a token counter.
    # @param chunk_size [Integer, nil] The maximum number of tokens a chunk may contain. Defaults to nil.
    # @param max_token_chars [Integer, nil] The maximum number of characters a token may contain. Defaults to nil.
    # @param memoize [Boolean] Whether to memoize the token counter. Defaults to true.
    # @param cache_maxsize [Integer, nil] The maximum number of text-token count pairs that can be stored in the token counter's cache.
    #
    # @return [Chunker] A chunker instance
    def chunkerify(tokenizer_or_token_counter, chunk_size: nil, max_token_chars: nil, memoize: true, cache_maxsize: nil)
      validate_tokenizer_type(tokenizer_or_token_counter)

      max_token_chars = determine_max_token_chars(tokenizer_or_token_counter, max_token_chars)
      chunk_size = determine_chunk_size(tokenizer_or_token_counter, chunk_size)
      token_counter = create_token_counter(tokenizer_or_token_counter)
      token_counter = wrap_with_fast_counter(token_counter, max_token_chars, chunk_size) if max_token_chars
      token_counter = memoize_token_counter(token_counter, cache_maxsize) if memoize

      Chunker.new(chunk_size: chunk_size, token_counter: token_counter)
    end

    private

    def validate_tokenizer_type(tokenizer_or_token_counter)
      return unless tokenizer_or_token_counter.is_a?(String)

      raise NotImplementedError,
            "String tokenizer names not yet supported in Ruby. Please pass a tokenizer object or token counter proc."
    end

    def determine_max_token_chars(tokenizer, max_token_chars)
      return max_token_chars unless max_token_chars.nil?

      if tokenizer.respond_to?(:token_byte_values)
        vocab = tokenizer.token_byte_values
        return vocab.map(&:length).max if vocab.respond_to?(:map)
      elsif tokenizer.respond_to?(:get_vocab)
        vocab = tokenizer.get_vocab
        return vocab.keys.map(&:length).max if vocab.respond_to?(:keys)
      end

      nil
    end

    def determine_chunk_size(tokenizer, chunk_size)
      return chunk_size unless chunk_size.nil?

      raise ArgumentError, "chunk_size not provided and tokenizer lacks model_max_length attribute" unless tokenizer.respond_to?(:model_max_length) && tokenizer.model_max_length.is_a?(Integer)

      chunk_size = tokenizer.model_max_length

      if tokenizer.respond_to?(:encode)
        begin
          chunk_size -= tokenizer.encode("").length
        rescue StandardError
          # Ignore errors
        end
      end

      chunk_size
    end

    def create_token_counter(tokenizer_or_token_counter)
      return tokenizer_or_token_counter unless tokenizer_or_token_counter.respond_to?(:encode)

      tokenizer = tokenizer_or_token_counter
      encode_params = begin
        tokenizer.method(:encode).parameters
      rescue StandardError
        []
      end

      has_special_tokens = encode_params.any? { |_type, name| name == :add_special_tokens }

      if has_special_tokens
        ->(text) { tokenizer.encode(text, add_special_tokens: false).length }
      else
        ->(text) { tokenizer.encode(text).length }
      end
    end

    def wrap_with_fast_counter(token_counter, max_token_chars, chunk_size)
      max_token_chars -= 1
      original_token_counter = token_counter

      lambda do |text|
        heuristic = chunk_size * 6
        if text.length > heuristic && original_token_counter.call(text[0...(heuristic + max_token_chars)]) > chunk_size
          chunk_size + 1
        else
          original_token_counter.call(text)
        end
      end
    end

    def split_text(text)
      splitter_is_whitespace = true

      # Try splitting at various levels
      if text.include?("\n") || text.include?("\r")
        newline_matches = text.scan(/[\r\n]+/)
        splitter = newline_matches.max_by(&:length)
      elsif text.include?("\t")
        tab_matches = text.scan(/\t+/)
        splitter = tab_matches.max_by(&:length)
      elsif text.match?(/\s/)
        whitespace_matches = text.scan(/\s+/)
        splitter = whitespace_matches.max_by(&:length)

        # If the splitter is only a single character, see if we can target whitespace preceded by semantic splitters
        if splitter.length == 1
          NON_WHITESPACE_SEMANTIC_SPLITTERS.each do |preceder|
            escaped_preceder = Regexp.escape(preceder)
            next unless (match = text.match(/#{escaped_preceder}(\s)/))

            splitter = match[1]
            escaped_splitter = Regexp.escape(splitter)
            return [splitter, splitter_is_whitespace, text.split(/(?<=#{escaped_preceder})#{escaped_splitter}/)]
          end
        end
      else
        # Find the most desirable semantically meaningful non-whitespace splitter
        splitter = NON_WHITESPACE_SEMANTIC_SPLITTERS.find { |s| text.include?(s) }

        return ["", splitter_is_whitespace, text.chars] unless splitter

        splitter_is_whitespace = false

        # No semantic splitter found, return characters

      end

      [splitter, splitter_is_whitespace, text.split(splitter)]
    end

    def bisect_left(sorted, target, low, high)
      while low < high
        mid = (low + high) / 2
        if sorted[mid] < target
          low = mid + 1
        else
          high = mid
        end
      end
      low
    end

    def merge_splits(splits:, cum_lens:, chunk_size:, splitter:, token_counter:, start:, high:)
      average = 0.2
      low = start

      offset = cum_lens[start]
      target = offset + (chunk_size * average)

      while low < high
        i = bisect_left(cum_lens, target, low, high)
        midpoint = [i, high - 1].min

        tokens = token_counter.call(splits[start...midpoint].join(splitter))

        local_cum = cum_lens[midpoint] - offset

        if local_cum.positive? && tokens.positive?
          average = local_cum.to_f / tokens
          target = offset + (chunk_size * average)
        end

        if tokens > chunk_size
          high = midpoint
        else
          low = midpoint + 1
        end
      end

      last_split_index = low - 1
      [last_split_index, splits[start...last_split_index].join(splitter)]
    end

    def memoize_token_counter(token_counter, maxsize=nil)
      return @memoized_token_counters[token_counter] if @memoized_token_counters.key?(token_counter)

      cache = {}
      queue = []

      memoized = lambda do |text|
        if cache.key?(text)
          cache[text]
        else
          result = token_counter.call(text)
          cache[text] = result

          if maxsize
            queue << text
            if queue.length > maxsize
              oldest = queue.shift
              cache.delete(oldest)
            end
          end

          result
        end
      end

      @memoized_token_counters[token_counter] = memoized
    end
  end
end
