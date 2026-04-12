# frozen_string_literal: true

require_relative "rodofs/version"
require_relative "rodofs/rodo_object"
require_relative "rodofs/fuse_dir"

# RodoFS - A Tag-Based Virtual Filesystem with Redis Backend
module RodoFS
  class Error < StandardError; end

  # Create and mount a RodoFS filesystem
  # @param lang [String] Language code (e.g., 'it', 'en')
  # @param redis_options [Hash] Redis connection options
  # @param mountpoint [String] Directory where to mount the filesystem
  # @return [void]
  def self.mount(lang: 'it', redis_options: { host: '127.0.0.1', port: 6379 }, mountpoint:)
    require 'redis'
    require 'rfusefs'

    unless File.directory?(mountpoint)
      raise Error, "#{mountpoint} is not a directory"
    end

    redis = Redis.new(redis_options)
    root = FuseDir.new(lang, redis)

    ::FuseFS.set_root(root)
    ::FuseFS.mount_under(mountpoint)
    ::FuseFS.run
  end
end
