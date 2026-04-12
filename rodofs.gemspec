# frozen_string_literal: true

require_relative "lib/rodofs/version"

Gem::Specification.new do |spec|
  spec.name = "rodofs"
  spec.version = RodoFS::VERSION
  spec.authors = ["Mirko Mariotti"]
  spec.email = ["info@mirkomariotti.it"]

  spec.summary = "A Tag-Based Virtual Filesystem with Redis Backend"
  spec.description = "RodoFS is a FUSE-based virtual filesystem that provides tag-based organization for your files using Redis as a persistent metadata store."
  spec.homepage = "https://github.com/mmirko/rodofs"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mmirko/rodofs"
  spec.metadata["changelog_uri"] = "https://github.com/mmirko/rodofs/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
    lib/**/*.rb
    bin/*
    scripts/*
    LICENSE
    README.md
    TODO
  ], File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "redis", "~> 4.0"
  spec.add_dependency "rfusefs", "~> 1.1"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
