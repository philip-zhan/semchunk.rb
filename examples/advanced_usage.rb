#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/semchunk"

# Advanced Example: Processing a longer document with various features

puts "=" * 70
puts "Advanced Semchunk Example: Document Processing"
puts "=" * 70

# Simulate a longer document
document = <<~TEXT
  Introduction to Natural Language Processing

  Natural language processing (NLP) is a subfield of linguistics, computer science,
  and artificial intelligence concerned with the interactions between computers and
  human language. In particular, it focuses on how to program computers to process
  and analyze large amounts of natural language data.

  The goal is a computer capable of understanding the contents of documents,
  including the contextual nuances of the language within them. The technology
  can then accurately extract information and insights contained in the documents
  as well as categorize and organize the documents themselves.

  Applications of NLP

  Modern NLP algorithms are based on machine learning, especially statistical
  machine learning. The paradigm of machine learning is different from that of
  most prior attempts at language processing. Prior implementations of
  language-processing tasks typically involved the direct hand coding of large
  sets of rules.

  Common applications include: machine translation, speech recognition, sentiment
  analysis, question answering, text summarization, and information extraction.
  These applications have transformed how we interact with technology today.
TEXT

# Define a sophisticated token counter that considers punctuation
def advanced_token_counter(text)
  # Count words and punctuation separately
  words = text.scan(/\w+/).length
  punctuation = text.scan(/[.,!?;:]/).length
  words + (punctuation * 0.5).ceil # Punctuation counts as half a token
end

puts "\nDocument Preview:"
puts document[0..200] + "..."
puts "\nDocument statistics:"
puts "  - Total characters: #{document.length}"
puts "  - Total tokens: #{advanced_token_counter(document)}"
puts "  - Lines: #{document.lines.count}"

# Example 1: Basic semantic chunking
puts "\n" + "=" * 70
puts "Example 1: Semantic Chunking (max 50 tokens per chunk)"
puts "=" * 70

chunks = Semchunk.chunk(
  document,
  chunk_size: 50,
  token_counter: method(:advanced_token_counter)
)

puts "\nCreated #{chunks.length} chunks:"
chunks.each_with_index do |chunk, i|
  token_count = advanced_token_counter(chunk)
  preview = chunk.gsub(/\s+/, ' ').strip[0..60]
  preview += "..." if chunk.length > 60
  puts "\n  Chunk #{i + 1} (#{token_count} tokens):"
  puts "    #{preview}"
end

# Example 2: With overlap for context preservation
puts "\n" + "=" * 70
puts "Example 2: Overlapping Chunks (30% overlap)"
puts "=" * 70

overlapping_chunks = Semchunk.chunk(
  document,
  chunk_size: 40,
  token_counter: method(:advanced_token_counter),
  overlap: 0.3
)

puts "\nCreated #{overlapping_chunks.length} overlapping chunks:"
puts "(showing first 3 chunks)"

overlapping_chunks.take(3).each_with_index do |chunk, i|
  puts "\n  Chunk #{i + 1}:"
  puts "    #{chunk.gsub(/\s+/, ' ').strip[0..80]}..."

  # Show overlap with next chunk
  if i < overlapping_chunks.length - 1
    next_chunk = overlapping_chunks[i + 1]
    # Find common words
    current_words = chunk.downcase.scan(/\w+/)
    next_words = next_chunk.downcase.scan(/\w+/)
    overlap_words = current_words & next_words
    puts "    → Overlaps with next chunk: #{overlap_words.length} common words"
  end
end

# Example 3: Tracking source locations with offsets
puts "\n" + "=" * 70
puts "Example 3: Tracking Source Locations"
puts "=" * 70

chunks_with_offsets, offsets = Semchunk.chunk(
  document,
  chunk_size: 60,
  token_counter: method(:advanced_token_counter),
  offsets: true
)

puts "\nChunks with their original positions:"
chunks_with_offsets.each_with_index do |chunk, i|
  start_pos, end_pos = offsets[i]
  first_line = chunk.lines.first.strip
  puts "\n  Chunk #{i + 1}:"
  puts "    Position: characters #{start_pos}-#{end_pos}"
  puts "    Starts with: '#{first_line[0..50]}...'"

  # Verify the offset is correct
  original = document[start_pos...end_pos]
  if chunk == original
    puts "    ✓ Offset verified"
  else
    puts "    ✗ Offset mismatch!"
  end
end

# Example 4: Using Chunkerify for multiple documents
puts "\n" + "=" * 70
puts "Example 4: Processing Multiple Documents"
puts "=" * 70

# Create a reusable chunker
chunker = Semchunk.chunkerify(
  method(:advanced_token_counter),
  chunk_size: 30
)

documents = [
  "Ruby is a dynamic, open source programming language with a focus on simplicity and productivity.",
  "Semantic chunking helps preserve the meaning and context of text when splitting it into smaller pieces.",
  "Machine learning models often require input text to be split into chunks that fit within token limits."
]

puts "\nProcessing #{documents.length} documents:"
all_chunks = chunker.call(documents)

all_chunks.each_with_index do |doc_chunks, i|
  puts "\n  Document #{i + 1}:"
  puts "    Original: #{documents[i][0..60]}..."
  puts "    Chunks: #{doc_chunks.length}"
  doc_chunks.each_with_index do |chunk, j|
    puts "      #{j + 1}. #{chunk[0..40]}..." if chunk.length > 40
    puts "      #{j + 1}. #{chunk}" if chunk.length <= 40
  end
end

# Example 5: Custom chunking strategy for code-like text
puts "\n" + "=" * 70
puts "Example 5: Custom Strategy for Structured Text"
puts "=" * 70

code_like_text = <<~CODE
  def process_data(input):
      # Step 1: Clean the data
      cleaned = input.strip().lower()

      # Step 2: Tokenize
      tokens = cleaned.split()

      # Step 3: Filter
      filtered = [t for t in tokens if len(t) > 2]

      return filtered
CODE

puts "\nOriginal code:"
puts code_like_text

# Use line count as token counter for code
line_counter = ->(text) { text.lines.count }

chunks_code = Semchunk.chunk(
  code_like_text,
  chunk_size: 3,  # Max 3 lines per chunk
  token_counter: line_counter
)

puts "\nChunked by semantic units (max 3 lines):"
chunks_code.each_with_index do |chunk, i|
  puts "\n  Segment #{i + 1}:"
  chunk.each_line { |line| puts "    #{line}" }
end

# Summary statistics
puts "\n" + "=" * 70
puts "Session Summary"
puts "=" * 70

puts "\nProcessed:"
puts "  - 1 main document (#{document.length} chars)"
puts "  - 3 additional documents"
puts "  - 1 code snippet"
puts "\nGenerated:"
puts "  - #{chunks.length} basic chunks"
puts "  - #{overlapping_chunks.length} overlapping chunks"
puts "  - #{chunks_with_offsets.length} chunks with offsets"
puts "\nAll examples completed successfully! ✓"
