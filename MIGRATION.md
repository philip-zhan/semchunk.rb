# Migration Guide: Python to Ruby

This document helps users familiar with the Python `semchunk` package transition to the Ruby gem.

## Installation

**Python:**
```bash
pip install semchunk
```

**Ruby:**
```bash
gem install semchunk
```

## Basic Usage

### Python

```python
from semchunk import chunk

text = "Hello world. How are you?"
token_counter = lambda text: len(text.split())

chunks = chunk(text, chunk_size=5, token_counter=token_counter)
```

### Ruby

```ruby
require "semchunk"

text = "Hello world. How are you?"
token_counter = ->(text) { text.split.length }

chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: token_counter)
```

## Key Differences

### 1. Import/Require

**Python:**
```python
from semchunk import chunk, chunkerify
```

**Ruby:**
```ruby
require "semchunk"
# Access via Semchunk.chunk and Semchunk.chunkerify
```

### 2. Lambda Syntax

**Python:**
```python
token_counter = lambda text: len(text.split())
```

**Ruby:**
```ruby
token_counter = ->(text) { text.split.length }
# or
token_counter = lambda { |text| text.split.length }
```

### 3. Named Parameters

Both languages support keyword arguments, but syntax differs slightly:

**Python:**
```python
chunks = chunk(text, chunk_size=10, token_counter=counter, memoize=True)
```

**Ruby:**
```ruby
chunks = Semchunk.chunk(text, chunk_size: 10, token_counter: counter, memoize: true)
```

Note: Ruby uses symbols (`:`) for keyword arguments and lowercase `true`/`false`.

### 4. Return Values with Offsets

**Python:**
```python
chunks, offsets = chunk(text, chunk_size=5, token_counter=counter, offsets=True)
```

**Ruby:**
```ruby
chunks, offsets = Semchunk.chunk(text, chunk_size: 5, token_counter: counter, offsets: true)
```

Unpacking works the same way in both languages!

### 5. Chunkerify

**Python:**
```python
from semchunk import chunkerify

chunker = chunkerify(token_counter, chunk_size=10)
chunks = chunker(text)
```

**Ruby:**
```ruby
chunker = Semchunk.chunkerify(token_counter, chunk_size: 10)
chunks = chunker.call(text)
```

Note: In Ruby, you must explicitly call `.call()` on the chunker.

### 6. Multiple Texts

**Python:**
```python
texts = ["First text", "Second text", "Third text"]
all_chunks = chunker(texts)
```

**Ruby:**
```ruby
texts = ["First text", "Second text", "Third text"]
all_chunks = chunker.call(texts)
```

## Complete Side-by-Side Example

### Python

```python
from semchunk import chunk, chunkerify

# Simple token counter
token_counter = lambda text: len(text.split())

# Basic chunking
text = "First sentence. Second sentence. Third sentence."
chunks = chunk(text, chunk_size=3, token_counter=token_counter)

# With offsets
chunks, offsets = chunk(
    text,
    chunk_size=3,
    token_counter=token_counter,
    offsets=True
)

# With overlap
chunks = chunk(
    text,
    chunk_size=5,
    token_counter=token_counter,
    overlap=0.5
)

# Using chunkerify
chunker = chunkerify(token_counter, chunk_size=5)
texts = ["Text 1", "Text 2", "Text 3"]
all_chunks = chunker(texts, processes=1, progress=False)
```

### Ruby

```ruby
require "semchunk"

# Simple token counter
token_counter = ->(text) { text.split.length }

# Basic chunking
text = "First sentence. Second sentence. Third sentence."
chunks = Semchunk.chunk(text, chunk_size: 3, token_counter: token_counter)

# With offsets
chunks, offsets = Semchunk.chunk(
  text,
  chunk_size: 3,
  token_counter: token_counter,
  offsets: true
)

# With overlap
chunks = Semchunk.chunk(
  text,
  chunk_size: 5,
  token_counter: token_counter,
  overlap: 0.5
)

# Using chunkerify
chunker = Semchunk.chunkerify(token_counter, chunk_size: 5)
texts = ["Text 1", "Text 2", "Text 3"]
all_chunks = chunker.call(texts, processes: 1, progress: false)
```

## Features Not Yet Implemented in Ruby

The following Python features are not yet available in the Ruby version:

1. **Parallel Processing**: The `processes` parameter is accepted but not yet functional
2. **Progress Bars**: The `progress` parameter is accepted but not yet functional
3. **String Tokenizer Names**: You cannot pass tokenizer names like `"gpt-4"` directly

For parallel processing in Ruby, you'll need to implement your own solution using threads or the `parallel` gem.

## Method Names

| Python | Ruby |
|--------|------|
| `chunk()` | `Semchunk.chunk()` |
| `chunkerify()` | `Semchunk.chunkerify()` |
| `chunker(text)` | `chunker.call(text)` |

## Ruby Idioms

When porting Python code, consider these Ruby best practices:

1. Use snake_case for variables and methods (Ruby convention)
2. Use symbols for keyword arguments
3. Prefer `Array#length` over `Array#size` for consistency with Python
4. Use `lambda` or `->` for anonymous functions instead of Python's `lambda`
5. Use `true`/`false`/`nil` instead of `True`/`False`/None`

## Error Handling

Error handling is similar between the two:

**Python:**
```python
try:
    chunks = chunk(text, chunk_size=5, token_counter=counter)
except ValueError as e:
    print(f"Error: {e}")
```

**Ruby:**
```ruby
begin
  chunks = Semchunk.chunk(text, chunk_size: 5, token_counter: counter)
rescue ArgumentError => e
  puts "Error: #{e}"
end
```

Note: Python's `ValueError` often corresponds to Ruby's `ArgumentError`.

## Working with Tokenizers

### Python (tiktoken example)

```python
import tiktoken
from semchunk import chunkerify

tokenizer = tiktoken.encoding_for_model("gpt-4")
chunker = chunkerify(tokenizer, chunk_size=100)
```

### Ruby (custom tokenizer)

```ruby
class CustomTokenizer
  def encode(text, add_special_tokens: false)
    text.split.map(&:hash)
  end
  
  def model_max_length
    512
  end
end

tokenizer = CustomTokenizer.new
chunker = Semchunk.chunkerify(tokenizer, chunk_size: 100)
```

## Performance Considerations

Both implementations use similar algorithms with comparable performance characteristics:

- Binary search for optimal split points
- Memoization/caching of token counts
- Hierarchical splitting strategy

The Ruby version should have similar performance to the Python version for most use cases.

## Getting Help

- **Ruby Gem Issues**: https://github.com/philip-zhan/semchunk.rb/issues
- **Python Package Issues**: https://github.com/umarbutler/semchunk/issues
- **Documentation**: See the [README.md](README.md) for detailed Ruby examples

