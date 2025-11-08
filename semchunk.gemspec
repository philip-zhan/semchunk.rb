# frozen_string_literal: true

require_relative "lib/semchunk/version"

Gem::Specification.new do |spec|
  spec.name = "semchunk"
  spec.version = Semchunk::VERSION
  spec.authors = ["Philip Zhan"]
  spec.email = ["h6zhan@gmail.com"]

  spec.summary = "Split text into semantically meaningful chunks. Ported from the Python `semchunk` package."
  spec.homepage = "https://github.com/philip-zhan/semchunk.rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/philip-zhan/semchunk.rb/issues",
    "changelog_uri" => "https://github.com/philip-zhan/semchunk.rb/releases",
    "source_code_uri" => "https://github.com/philip-zhan/semchunk.rb",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  # spec.add_dependency "thor", "~> 1.2"
end
