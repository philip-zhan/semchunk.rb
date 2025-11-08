#!/usr/bin/env ruby
# frozen_string_literal: true

require "semchunk"
require "benchmark"

# Benchmark configuration
CHUNK_SIZE = 512

# Sample texts for benchmarking (simulating NLTK's Gutenberg corpus)
SAMPLE_TEXTS = [
  # Pride and Prejudice excerpt
  <<~TEXT,
    It is a truth universally acknowledged, that a single man in possession of a good fortune,
    must be in want of a wife. However little known the feelings or views of such a man may be
    on his first entering a neighbourhood, this truth is so well fixed in the minds of the
    surrounding families, that he is considered the rightful property of some one or other of
    their daughters.
  TEXT
  # Moby Dick excerpt
  <<~TEXT,
    Call me Ishmael. Some years ago—never mind how long precisely—having little or no money in
    my purse, and nothing particular to interest me on shore, I thought I would sail about a
    little and see the watery part of the world. It is a way I have of driving off the spleen
    and regulating the circulation.
  TEXT
  # Alice in Wonderland excerpt
  <<~TEXT,
    Alice was beginning to get very tired of sitting by her sister on the bank, and of having
    nothing to do: once or twice she had peeped into the book her sister was reading, but it
    had no pictures or conversations in it, "and what is the use of a book," thought Alice
    "without pictures or conversations?"
  TEXT
  # Tale of Two Cities excerpt
  <<~TEXT,
    It was the best of times, it was the worst of times, it was the age of wisdom, it was the
    age of foolishness, it was the epoch of belief, it was the epoch of incredulity, it was the
    season of Light, it was the season of Darkness, it was the spring of hope, it was the winter
    of despair.
  TEXT
  # Frankenstein excerpt
  <<~TEXT
    You will rejoice to hear that no disaster has accompanied the commencement of an enterprise
    which you have regarded with such evil forebodings. I arrived here yesterday, and my first
    task is to assure my dear sister of my welfare and increasing confidence in the success of
    my undertaking.
  TEXT
].freeze

def bench_semchunk(texts, chunk_size)
  # Simple word-based token counter (approximation)
  token_counter = ->(text) { text.split.length }

  chunker = Semchunk.chunkerify(token_counter, chunk_size: chunk_size)

  texts.each do |text|
    chunker.call(text)
  end
end

def run_benchmark
  puts "=" * 70
  puts "Semchunk Benchmark"
  puts "=" * 70
  puts "\nConfiguration:"
  puts "  Chunk size: #{CHUNK_SIZE} tokens"
  puts "  Number of texts: #{SAMPLE_TEXTS.length}"
  puts "  Total characters: #{SAMPLE_TEXTS.sum(&:length)}"
  puts "  Token counter: word-based (simple split)"

  # Warm up
  puts "\nWarming up..."
  bench_semchunk(SAMPLE_TEXTS, CHUNK_SIZE)

  # Benchmark
  puts "\nRunning benchmark..."

  time = Benchmark.realtime do
    10.times do
      bench_semchunk(SAMPLE_TEXTS, CHUNK_SIZE)
    end
  end

  average_time = time / 10

  puts "\nResults:"
  puts "  Total time (10 iterations): #{time.round(3)}s"
  puts "  Average time per iteration: #{average_time.round(3)}s"
  puts "  Chunks per second: #{(SAMPLE_TEXTS.length / average_time).round(0)}"

  # Show sample output
  puts "\n#{'=' * 70}"
  puts "Sample Output (first text):"
  puts "=" * 70

  token_counter = ->(text) { text.split.length }
  chunker = Semchunk.chunkerify(token_counter, chunk_size: 50)
  chunks = chunker.call(SAMPLE_TEXTS.first)

  puts "\nOriginal text length: #{SAMPLE_TEXTS.first.length} characters"
  puts "Number of chunks: #{chunks.length}"
  puts "\nFirst 3 chunks:"
  chunks.take(3).each_with_index do |chunk, i|
    preview = chunk.gsub(/\s+/, " ").strip[0..60]
    preview += "..." if chunk.length > 60
    puts "  #{i + 1}. #{preview}"
    puts "     (#{token_counter.call(chunk)} tokens)"
  end

  # Memory usage test
  puts "\n#{'=' * 70}"
  puts "Memory Efficiency Test"
  puts "=" * 70

  large_text = SAMPLE_TEXTS.join("\n\n") * 10
  puts "\nProcessing large text:"
  puts "  Size: #{large_text.length} characters"
  puts "  Estimated tokens: ~#{large_text.split.length}"

  start_time = Time.now
  chunks_large = chunker.call(large_text)
  duration = Time.now - start_time

  puts "  Processing time: #{duration.round(3)}s"
  puts "  Chunks created: #{chunks_large.length}"
  puts "  Average chunk size: #{chunks_large.sum(&:length) / chunks_large.length} characters"

  puts "\n#{'=' * 70}"
  puts "Benchmark completed!"
  puts "=" * 70
end

run_benchmark if __FILE__ == $PROGRAM_NAME
