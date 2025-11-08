# Quick Start Guide

Get started with Semchunk in 5 minutes!

## Installation

```bash
# From the project directory
gem build semchunk.gemspec
gem install semchunk-0.1.0.gem

# Or add to your Gemfile
gem 'semchunk', path: '/path/to/semchunk.rb'
```

## Your First Chunk

Create a file `test_semchunk.rb`:

```ruby
require "semchunk"

# 1. Define a token counter (simple word counter)
token_counter = ->(text) { text.split.length }

# 2. Prepare your text
text = "Ruby is awesome. Semchunk makes text chunking easy. Let's try it out!"

# 3. Chunk it!
chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)

# 4. See the results
puts "Original text:"
puts text
puts "\nChunks (max 5 words each):"
chunks.each_with_index do |chunk, i|
  puts "#{i + 1}. #{chunk}"
end
```

Run it:

```bash
ruby test_semchunk.rb
```

Expected output:

```
Original text:
Ruby is awesome. Semchunk makes text chunking easy. Let's try it out!

Chunks (max 5 words each):
1. Ruby is awesome. Semchunk makes
2. text chunking easy. Let's try
3. it out!
```

## Next Steps

### With Offsets

```ruby
chunks, offsets = Semchunk.chunk(
  text, 
  chunk_size: 5, 
  token_counter: token_counter,
  offsets: true
)

chunks.zip(offsets).each do |chunk, (start, stop)|
  puts "#{chunk} -> [#{start}:#{stop}]"
end
```

### With Overlap

```ruby
chunks = Semchunk.chunk(
  text,
  chunk_size: 5,
  token_counter: token_counter,
  overlap: 0.5  # 50% overlap
)
```

### Process Multiple Texts

```ruby
chunker = Semchunk.chunkerify(token_counter, chunk_size: 10)

texts = [
  "First document here.",
  "Second document here.",
  "Third document here."
]

all_chunks = chunker.call(texts)
```

## Run the Examples

```bash
# Basic examples
ruby examples/basic_usage.rb

# Advanced examples
ruby examples/advanced_usage.rb
```

## Run the Tests

```bash
ruby -Ilib:test test/semchunk_test.rb
```

## Learn More

- [README.md](README.md) - Complete documentation
- [MIGRATION.md](MIGRATION.md) - Python to Ruby migration guide
- [PORT_SUMMARY.md](PORT_SUMMARY.md) - Technical details of the port

## Common Token Counters

### Word Counter
```ruby
->(text) { text.split.length }
```

### Character Counter
```ruby
->(text) { text.length }
```

### Custom Counter (words + punctuation)
```ruby
->(text) { text.scan(/\w+|[^\w\s]/).length }
```

### With a Tokenizer
```ruby
# If you have a tokenizer with an encode method:
chunker = Semchunk.chunkerify(my_tokenizer, chunk_size: 100)
```

Happy chunking! 🎉

