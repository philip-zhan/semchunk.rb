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
    def chunk(text, chunk_size:, token_counter:, memoize: true, offsets: false, overlap: nil, cache_maxsize: nil, recursion_depth: 0, start: 0)
      # Rename variables for clarity
      return_offsets = offsets
      local_chunk_size = chunk_size

      # If this is the first call, memoize the token counter if memoization is enabled and reduce the effective chunk size if overlapping chunks
      is_first_call = recursion_depth.zero?

      if is_first_call
        if memoize
          token_counter = memoize_token_counter(token_counter, cache_maxsize)
        end

        if overlap
          # Make relative overlaps absolute and floor both relative and absolute overlaps
          overlap = if overlap < 1
                      (chunk_size * overlap).floor
                    else
                      [overlap, chunk_size - 1].min
                    end

          # If the overlap has not been zeroed, compute the effective chunk size
          if overlap.positive?
            unoverlapped_chunk_size = chunk_size - overlap
            local_chunk_size = [overlap, unoverlapped_chunk_size].min
          end
        end
      end

      # Split the text using the most semantically meaningful splitter possible
      splitter, splitter_is_whitespace, splits = split_text(text)

      offsets_arr = []
      splitter_len = splitter.length
      split_lens = splits.map(&:length)
      cum_lens = [0]
      split_lens.each { |len| cum_lens << cum_lens.last + len }

      split_starts = [0]
      split_lens.each_with_index do |split_len, i|
        split_starts << split_starts[i] + split_len + splitter_len
      end
      split_starts = split_starts.map { |s| s + start }

      num_splits_plus_one = splits.length + 1

      chunks = []
      skips = Set.new

      # Iterate through the splits
      splits.each_with_index do |split, i|
        # Skip the split if it has already been added to a chunk
        next if skips.include?(i)

        split_start = split_starts[i]

        # If the split is over the chunk size, recursively chunk it
        if token_counter.call(split) > local_chunk_size
          new_chunks, new_offsets = chunk(
            split,
            chunk_size: local_chunk_size,
            token_counter: token_counter,
            offsets: true,
            recursion_depth: recursion_depth + 1,
            start: split_start
          )

          chunks.concat(new_chunks)
          offsets_arr.concat(new_offsets)
        else
          # Merge the split with subsequent splits until the chunk size is reached
          final_split_in_chunk_i, new_chunk = merge_splits(
            splits: splits,
            cum_lens: cum_lens,
            chunk_size: local_chunk_size,
            splitter: splitter,
            token_counter: token_counter,
            start: i,
            high: num_splits_plus_one
          )

          # Mark any splits included in the new chunk for exclusion from future chunks
          ((i + 1)...final_split_in_chunk_i).each { |j| skips.add(j) }

          # Add the chunk
          chunks << new_chunk

          # Add the chunk's offsets
          split_end = split_starts[final_split_in_chunk_i] - splitter_len
          offsets_arr << [split_start, split_end]
        end

        # If the splitter is not whitespace and the split is not the last split, add the splitter to the end of the latest chunk
        unless splitter_is_whitespace || (i == splits.length - 1 || ((i + 1)...splits.length).all? { |j| skips.include?(j) })
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
      end

      # If this is the first call, remove empty chunks and overlap if desired
      if is_first_call
        # Remove empty chunks and chunks comprised entirely of whitespace
        chunks_and_offsets = chunks.zip(offsets_arr).reject { |chunk, _| chunk.empty? || chunk.strip.empty? }

        if chunks_and_offsets.any?
          chunks, offsets_arr = chunks_and_offsets.transpose
        else
          chunks = []
          offsets_arr = []
        end

        # Overlap chunks if desired and there are chunks to overlap
        if overlap && overlap.positive? && chunks.any?
          # Rename variables for clarity
          subchunk_size = local_chunk_size
          subchunks = chunks
          suboffsets = offsets_arr
          num_subchunks = subchunks.length

          # Merge the subchunks into overlapping chunks
          subchunks_per_chunk = (chunk_size.to_f / subchunk_size).floor
          subchunk_stride = (unoverlapped_chunk_size.to_f / subchunk_size).floor

          num_overlapping_chunks = [1, ((num_subchunks - subchunks_per_chunk).to_f / subchunk_stride).ceil + 1].max

          offsets_arr = (0...num_overlapping_chunks).map do |i|
            start_idx = i * subchunk_stride
            end_idx = [start_idx + subchunks_per_chunk, num_subchunks].min - 1
            [suboffsets[start_idx][0], suboffsets[end_idx][1]]
          end

          chunks = offsets_arr.map { |s, e| text[s...e] }
        end

        # Return offsets if desired
        return [chunks, offsets_arr] if return_offsets

        return chunks
      end

      # Always return chunks and offsets if this is a recursive call
      [chunks, offsets_arr]
    end

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
      # Handle string tokenizer names (would require tiktoken/transformers Ruby equivalents)
      if tokenizer_or_token_counter.is_a?(String)
        raise NotImplementedError, "String tokenizer names not yet supported in Ruby. Please pass a tokenizer object or token counter proc."
      end

      # Determine max_token_chars if not provided
      if max_token_chars.nil?
        if tokenizer_or_token_counter.respond_to?(:token_byte_values)
          vocab = tokenizer_or_token_counter.token_byte_values
          max_token_chars = vocab.map(&:length).max if vocab.respond_to?(:map)
        elsif tokenizer_or_token_counter.respond_to?(:get_vocab)
          vocab = tokenizer_or_token_counter.get_vocab
          max_token_chars = vocab.keys.map(&:length).max if vocab.respond_to?(:keys)
        end
      end

      # Determine chunk_size if not provided
      if chunk_size.nil?
        if tokenizer_or_token_counter.respond_to?(:model_max_length) && tokenizer_or_token_counter.model_max_length.is_a?(Integer)
          chunk_size = tokenizer_or_token_counter.model_max_length

          # Attempt to reduce the chunk size by the number of special characters
          if tokenizer_or_token_counter.respond_to?(:encode)
            begin
              chunk_size -= tokenizer_or_token_counter.encode("").length
            rescue StandardError
              # Ignore errors
            end
          end
        else
          raise ArgumentError, "chunk_size not provided and tokenizer lacks model_max_length attribute"
        end
      end

      # Construct token counter from tokenizer if needed
      if tokenizer_or_token_counter.respond_to?(:encode)
        tokenizer = tokenizer_or_token_counter
        # Check if encode accepts add_special_tokens parameter
        encode_params = tokenizer.method(:encode).parameters rescue []
        has_special_tokens = encode_params.any? { |type, name| name == :add_special_tokens }

        token_counter = if has_special_tokens
                          ->(text) { tokenizer.encode(text, add_special_tokens: false).length }
                        else
                          ->(text) { tokenizer.encode(text).length }
                        end
      else
        token_counter = tokenizer_or_token_counter
      end

      # Add fast token counter optimization if max_token_chars is known
      if max_token_chars
        max_token_chars -= 1
        original_token_counter = token_counter

        token_counter = lambda do |text|
          heuristic = chunk_size * 6
          if text.length > heuristic && original_token_counter.call(text[0...(heuristic + max_token_chars)]) > chunk_size
            chunk_size + 1
          else
            original_token_counter.call(text)
          end
        end
      end

      # Memoize the token counter if necessary
      if memoize
        token_counter = memoize_token_counter(token_counter, cache_maxsize)
      end

      # Construct and return the chunker
      Chunker.new(chunk_size: chunk_size, token_counter: token_counter)
    end

    private

    # A tuple of semantically meaningful non-whitespace splitters
    NON_WHITESPACE_SEMANTIC_SPLITTERS = [
      # Sentence terminators
      ".", "?", "!", "*",
      # Clause separators
      ";", ",", "(", ")", "[", "]", """, """, "'", "'", "'", '"', "`",
      # Sentence interrupters
      ":", "—", "…",
      # Word joiners
      "/", "\\", "–", "&", "-"
    ].freeze

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
            if (match = text.match(/#{escaped_preceder}(\s)/))
              splitter = match[1]
              escaped_splitter = Regexp.escape(splitter)
              return [splitter, splitter_is_whitespace, text.split(/(?<=#{escaped_preceder})#{escaped_splitter}/)]
            end
          end
        end
      else
        # Find the most desirable semantically meaningful non-whitespace splitter
        splitter = NON_WHITESPACE_SEMANTIC_SPLITTERS.find { |s| text.include?(s) }

        if splitter
          splitter_is_whitespace = false
        else
          # No semantic splitter found, return characters
          return ["", splitter_is_whitespace, text.chars]
        end
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

    def memoize_token_counter(token_counter, maxsize = nil)
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
