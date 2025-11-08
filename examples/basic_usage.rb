#!/usr/bin/env ruby
# frozen_string_literal: true

require "semchunk"

# Example 1: Basic chunking
puts "=" * 60
puts "Example 1: Basic Chunking"
puts "=" * 60

text = "This is the first sentence. This is the second sentence. And this is the third sentence with more words."
token_counter = ->(text) { text.split.length }

chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

puts "\nOriginal text:"
puts text
puts "\nChunks (max 5 tokens each):"
chunks.each_with_index do |chunk, i|
  puts "  #{i + 1}. #{chunk} (#{token_counter.call(chunk)} tokens)"
end

# Example 2: Chunking with offsets
puts "\n#{'=' * 60}"
puts "Example 2: Chunking with Offsets"
puts "=" * 60

text2 = "First paragraph. Second paragraph. Third paragraph."
chunks, offsets = Semchunk.chunk(text2, chunk_size: 3, token_counter: token_counter, offsets: true)

puts "\nOriginal text:"
puts text2
puts "\nChunks with offsets:"
chunks.zip(offsets).each_with_index do |(chunk, (start_pos, end_pos)), i|
  puts "  #{i + 1}. '#{chunk}' [#{start_pos}...#{end_pos}]"
  puts "     Verification: '#{text2[start_pos...end_pos]}' ✓" if chunk == text2[start_pos...end_pos]
end

# Example 3: Overlapping chunks
puts "\n#{'=' * 60}"
puts "Example 3: Overlapping Chunks"
puts "=" * 60

text3 = "One two three four five six seven eight nine ten."
puts "\nOriginal text:"
puts text3

puts "\nWithout overlap (chunk_size=4):"
chunks_no_overlap = Semchunk.chunk(text3, chunk_size: 4, token_counter: token_counter)
chunks_no_overlap.each_with_index { |chunk, i| puts "  #{i + 1}. #{chunk}" }

puts "\nWith 50% overlap (chunk_size=4, overlap=0.5):"
chunks_overlap = Semchunk.chunk(text3, chunk_size: 4, token_counter: token_counter, overlap: 0.5)
chunks_overlap.each_with_index { |chunk, i| puts "  #{i + 1}. #{chunk}" }

# Example 4: Using Chunkerify
puts "\n#{'=' * 60}"
puts "Example 4: Using Chunkerify for Multiple Texts"
puts "=" * 60

chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)

texts = [
  "Natural language processing is amazing.",
  "Ruby is a beautiful programming language.",
  "Semantic chunking preserves meaning."
]

puts "\nProcessing multiple texts:"
all_chunks = chunker.call(texts)

all_chunks.each_with_index do |doc_chunks, i|
  puts "\nDocument #{i + 1}: '#{texts[i]}'"
  doc_chunks.each_with_index do |chunk, j|
    puts "  Chunk #{j + 1}: #{chunk}"
  end
end

# Example 5: Character-level chunking
puts "\n#{'=' * 60}"
puts "Example 5: Character-Level Chunking"
puts "=" * 60

text5 = "abcdefghijklmnopqrstuvwxyz"
char_counter = lambda(&:length)

chunks_chars = Semchunk.chunk(text5, chunk_size: 5, token_counter: char_counter)

puts "\nOriginal text:"
puts text5
puts "\nChunks (max 5 characters each):"
chunks_chars.each_with_index do |chunk, i|
  puts "  #{i + 1}. #{chunk} (#{chunk.length} chars)"
end

puts "\n#{'=' * 60}"
puts "All examples completed!"
puts "=" * 60
