# frozen_string_literal: true

require "test_helper"

class SemchunkTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Semchunk::VERSION
  end
end
