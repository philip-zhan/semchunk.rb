# Semchunk

[![Gem Version](https://img.shields.io/gem/v/semchunk)](https://rubygems.org/gems/semchunk)
[![Gem Downloads](https://img.shields.io/gem/dt/semchunk)](https://www.ruby-toolbox.com/projects/semchunk)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/philip-zhan/semchunk.rb/ci.yml)](https://github.com/philip-zhan/semchunk.rb/actions/workflows/ci.yml)

Split text into semantically meaningful chunks of a specified size as determined by a provided token counter.

This is a Ruby port of the Python [semchunk](https://github.com/umarbutler/semchunk) package.

## Features

- **Semantic chunking**: Splits text at natural boundaries (sentences, paragraphs, etc.) rather than at arbitrary character positions
- **Token-aware**: Respects token limits from any tokenizer you provide
- **Overlap support**: Create overlapping chunks for better context preservation
- **Offset tracking**: Get the original positions of each chunk in the source text
- **Flexible**: Works with any token counter (word count, character count, or tokenizers)
- **Memoization**: Optional caching of token counts for improved performance

---

- [Installation](#installation)
- [Quick start](#quick-start)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Support](#support)
- [License](#license)
- [Code of conduct](#code-of-conduct)
- [Contribution guide](#contribution-guide)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'semchunk'
```

Or install it directly:

```bash
gem install semchunk
```

## Quick start

```ruby
require "semchunk"

# Define a simple token counter (or use a real tokenizer)
token_counter = ->(text) { text.split.length }

# Chunk some text
text = "This is the first sentence. This is the second sentence. And this is the third sentence."
chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

puts chunks.inspect
# => ["This is the first sentence.", "This is the second sentence.", "And this is the third sentence."]
```

## API Reference

### `Semchunk.chunk`

Split a text into semantically meaningful chunks.

```ruby
Semchunk.chunk(
  text,
  chunk_size:,
  token_counter:,
  memoize: true,
  offsets: false,
  overlap: nil,
  cache_maxsize: nil
)
```

**Parameters:**
- `text` (String): The text to be chunked
- `chunk_size` (Integer): The maximum number of tokens a chunk may contain
- `token_counter` (Proc, Lambda, Method): A callable that takes a string and returns the number of tokens in it
- `memoize` (Boolean, optional): Whether to memoize the token counter. Defaults to `true`
- `offsets` (Boolean, optional): Whether to return the start and end offsets of each chunk. Defaults to `false`
- `overlap` (Float, Integer, nil, optional): The proportion of the chunk size (if < 1), or the number of tokens (if >= 1), by which chunks should overlap. Defaults to `nil`
- `cache_maxsize` (Integer, nil, optional): The maximum number of text-token count pairs to cache. Defaults to `nil` (unbounded)

**Returns:**
- `Array<String>` if `offsets: false`: List of text chunks
- `[Array<String>, Array<Array<Integer>>]` if `offsets: true`: List of chunks and their `[start, end]` offsets

### `Semchunk.chunkerify`

Create a reusable chunker object.

```ruby
Semchunk.chunkerify(
  tokenizer_or_token_counter,
  chunk_size: nil,
  max_token_chars: nil,
  memoize: true,
  cache_maxsize: nil
)
```

**Parameters:**
- `tokenizer_or_token_counter`: A tokenizer object with an `encode` method, or a callable token counter
- `chunk_size` (Integer, nil): Maximum tokens per chunk. If `nil`, will attempt to use tokenizer's `model_max_length`
- `max_token_chars` (Integer, nil): Maximum characters per token (optimization parameter)
- `memoize` (Boolean): Whether to cache token counts. Defaults to `true`
- `cache_maxsize` (Integer, nil): Cache size limit. Defaults to `nil` (unbounded)

**Returns:**
- `Semchunk::Chunker`: A chunker instance

### `Chunker#call`

Process text(s) with the chunker.

```ruby
chunker.call(
  text_or_texts,
  processes: 1,
  progress: false,
  offsets: false,
  overlap: nil
)
```

**Parameters:**
- `text_or_texts` (String, Array<String>): Single text or array of texts to chunk
- `processes` (Integer): Number of processes for parallel chunking (not yet implemented)
- `progress` (Boolean): Show progress bar for multiple texts (not yet implemented)
- `offsets` (Boolean): Return offset information
- `overlap` (Float, Integer, nil): Overlap configuration

**Returns:**
- For single text: `Array<String>` or `[Array<String>, Array<Array<Integer>>]`
- For multiple texts: `Array<Array<String>>` or `[Array<Array<String>>, Array<Array<Array<Integer>>>]`

## Examples

### Basic Chunking

```ruby
require "semchunk"

text = "Natural language processing is fascinating. It allows computers to understand human language. This enables many applications."

# Use word count as token counter
token_counter = ->(text) { text.split.length }

chunks = Semchunk.chunk(text, chunk_size: 8, token_counter: token_counter)

chunks.each_with_index do |chunk, i|
  puts "Chunk #{i + 1}: #{chunk}"
end
# => Chunk 1: Natural language processing is fascinating. It allows computers
# => Chunk 2: to understand human language. This enables many applications.
```

### With Offsets

Track where each chunk came from in the original text:

```ruby
text = "First paragraph here. Second paragraph here. Third paragraph here."
token_counter = ->(text) { text.split.length }

chunks, offsets = Semchunk.chunk(
  text,
  chunk_size: 5,
  token_counter: token_counter,
  offsets: true
)

chunks.zip(offsets).each do |chunk, (start_pos, end_pos)|
  puts "Chunk: '#{chunk}'"
  puts "Position: #{start_pos}...#{end_pos}"
  puts "Verification: '#{text[start_pos...end_pos]}'"
  puts
end
```

### With Overlap

Create overlapping chunks to maintain context:

```ruby
text = "One two three four five six seven eight nine ten."
token_counter = ->(text) { text.split.length }

# 50% overlap
chunks = Semchunk.chunk(
  text,
  chunk_size: 4,
  token_counter: token_counter,
  overlap: 0.5
)

puts "Overlapping chunks:"
chunks.each { |chunk| puts "- #{chunk}" }

# Fixed overlap of 2 tokens
chunks = Semchunk.chunk(
  text,
  chunk_size: 6,
  token_counter: token_counter,
  overlap: 2
)

puts "\nWith 2-token overlap:"
chunks.each { |chunk| puts "- #{chunk}" }
```

### Using Chunkerify for Reusable Chunkers

```ruby
# Create a chunker once
token_counter = ->(text) { text.split.length }
chunker = Semchunk.chunkerify(token_counter, chunk_size: 10)

# Use it multiple times
texts = [
  "First document to process.",
  "Second document to process.",
  "Third document to process."
]

all_chunks = chunker.call(texts)

all_chunks.each_with_index do |chunks, i|
  puts "Document #{i + 1} chunks: #{chunks.inspect}"
end
```

### Character-Level Chunking

```ruby
text = "abcdefghijklmnopqrstuvwxyz"

# Character count as token counter
token_counter = ->(text) { text.length }

chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

puts chunks.inspect
# => ["abcde", "fghij", "klmno", "pqrst", "uvwxy", "z"]
```

### Custom Token Counter

```ruby
# Token counter that counts punctuation as separate tokens
def custom_token_counter(text)
  text.scan(/\w+|[^\w\s]/).length
end

text = "Hello, world! How are you?"

chunks = Semchunk.chunk(
  text,
  chunk_size: 5,
  token_counter: method(:custom_token_counter)
)

puts chunks.inspect
```

### Working with Real Tokenizers

If you have a tokenizer that implements an `encode` method:

```ruby
# Example with a hypothetical tokenizer
class MyTokenizer
  def encode(text, add_special_tokens: true)
    # Your tokenization logic here
    text.split.map { |word| word.hash }
  end
  
  def model_max_length
    512
  end
end

tokenizer = MyTokenizer.new

# chunkerify will automatically extract the token counter
chunker = Semchunk.chunkerify(tokenizer, chunk_size: 100)

text = "Your long text here..."
chunks = chunker.call(text)
```

## How It Works

Semchunk uses a hierarchical splitting strategy:

1. **Primary split**: Tries to split on paragraph breaks (newlines)
2. **Secondary split**: Falls back to sentences (periods, question marks, etc.)
3. **Tertiary split**: Uses clauses (commas, semicolons) if needed
4. **Final split**: Character-level splitting as last resort

This ensures that chunks are semantically meaningful while respecting your token limits.

The algorithm uses binary search to efficiently find the optimal split points, making it fast even for large documents.

## Running the Examples

This gem includes example scripts that demonstrate various features:

```bash
# Basic usage examples
ruby examples/basic_usage.rb

# Advanced usage with longer documents
ruby examples/advanced_usage.rb
```

## Differences from Python Version

This Ruby port maintains feature parity with the Python version, with a few notes:

- Multiprocessing support is not yet implemented (`processes` parameter)
- Progress bar support is not yet implemented (`progress` parameter)  
- String tokenizer names (like `"gpt-4"`) are not yet supported
- Otherwise, the API and behavior match the Python version

See [MIGRATION.md](MIGRATION.md) for a detailed guide on migrating from the Python version.

## Support

If you want to report a bug, or have ideas, feedback or questions about the gem, [let me know via GitHub issues](https://github.com/philip-zhan/semchunk.rb/issues/new) and I will do my best to provide a helpful answer. Happy hacking!

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of conduct

Everyone interacting in this project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Contribution guide

Pull requests are welcome!
