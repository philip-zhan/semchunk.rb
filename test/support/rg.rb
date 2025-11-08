# frozen_string_literal: true

# Enable color test output (optional)
begin
  require "minitest/rg"
rescue LoadError
  # minitest-rg not installed, test output will be plain
end
