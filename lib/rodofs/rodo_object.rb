# frozen_string_literal: true

require 'redis'

module RodoFS
  # RodoObject represents objects in the RodoFS system with Redis synchronization
  class RodoObject
    @@lds = [:label]  # the list of language dependent keys

    attr_accessor :oid      # The id, may be nil. otherwise is a radis key id (composed from the object type)
    attr_accessor :synced   # The synced status: 0 - async, 1 - synced
    attr_accessor :standalone
    attr_accessor :useall

    #   @lang         # The object language, or nil or 'all'
    #   @r            # The redis instance, or nil
    #   @type         # The object type
    #   @prefix       # The prefix used for storing the object keys in the KV store
    #   @keys         # The actual keys hash
    #   @listed_types # An hash that list for each key whose value is a list which is the inner object type

    def initialize(type, lang = nil, server = nil)
      # The main instance parameters
      @oid = nil
      @synced = 0
      @standalone = false

      @lang = lang
      @r = server

      @old_remote = {}
      @new_remote = {}
      @old_local = {}
      @new_local = {}

      # Populating the instance schema
      case type
      when "Rresource"
        @type = type
        @prefix = 'res'
        @keys = [:label, :tags, :md5, :url, :mime]
        @listed_types = { tags: ["Rtag", :res] }
        @useall = true
      when "Rtax"
        @type = type
        @prefix = 'tax'
        @keys = [:label, :tags]
        @listed_types = { tags: ["Rtag", :tax] }
        @useall = true
      when "Rtag"
        @type = type
        @prefix = 'tag'
        @keys = [:label, :tax, :res]
        @listed_types = { tax: ["Rtax", :tags], res: ["Rresource", :tags] }
        @useall = true
      when "Rrule"
        @type = type
        @prefix = 'rul'
        @keys = [:label, :rule]
        @listed_types = {}
        @useall = true
      when "Rauto"
        @type = type
        @prefix = 'aut'
        @keys = [:label, :urlmatch, :tagset]
        @listed_types = {}
        @useall = true
      else
        raise ArgumentError, "No valid object type"
      end
    end

    # Override the class method
    def class
      @type
    end

    # Return the list of the object keys
    def keys
      @keys
    end

    # Return the list of the object keys (unlisted)
    def unlisted_keys
      ret = []
      @keys.each do |key|
        ret << key unless @listed_types.include?(key)
      end
      ret
    end

    def oid=(new_oid)
      unless new_oid.is_a?(Integer)
        puts "Only integer oid"
        puts inspect
        return
      end

      @oid = if new_oid.zero?
               @r.incr(@prefix + ':curr')
             else
               new_oid
             end

      @r.sadd(@prefix + ':all', @oid) if !standalone && useall

      @old_remote = {}
      @new_remote = {}
      @old_local = {}
      @new_local = {}
    end

    def deloid
      if @oid.nil?
        puts "Delete is only allowed with not nil oid"
        return
      end

      @r.srem(@prefix + ':all', @oid) if !standalone && useall

      @keys.each do |key|
        kstr = key_to_string(key)
        @r.del(kstr) if @r.exists?(kstr)
      end

      @oid = nil
      @old_remote = {}
      @new_remote = {}
      @old_local = {}
      @new_local = {}
    end

    # Global search over the useall elements
    def search(var, value)
      if !@oid.nil?
        puts "Search is only allowed with nil oid"
        return
      end

      unless useall
        puts "Search is only allowed on types with useall enabled"
        return
      end

      if @listed_types.include?(var)
        puts "Search is only allowed on unlisted types"
        return
      end

      allmembers = @r.smembers(@prefix + ':all')

      allmembers.each do |ioid|
        ret = "#{@prefix}:#{ioid}:#{var}"
        ret += ":#{@lang}" if @@lds.include?(var) && !@lang.nil?

        if @r.exists?(ret)
          ckvalue = @r.get(ret)
          if ckvalue == value
            @oid = ioid.to_i
            break
          end
        end
      end
      @oid
    end

    # Inner search within a given set
    def inner_search(search_key, var, value)
      if @oid.nil?
        puts "Search is only allowed with no nil oid"
        return nil
      end
      unless @listed_types.include?(search_key)
        puts "Search is only allowed on listed types"
        return nil
      end

      allmembers = @new_local[search_key] || []
      type = @listed_types[search_key][0]
      auxobj = RodoObject.new(type, @lang, @r)

      allmembers.each do |ioid|
        auxobj.oid = ioid.to_i
        auxobj.sync_key(var)
        ckvalue = auxobj.get(var)

        return ioid.to_i if ckvalue == value
      end
      nil
    end

    # Add an element to a list
    def add(var, member)
      sync_set(var, member)
      real_add(var, member)
      sync_set(var, member)
    end

    # Del an element from a list
    def del(var, member)
      sync_set(var, member)
      real_del(var, member)
      sync_set(var, member)
    end

    # Internal add
    def real_add(var, member)
      return nil unless @listed_types.include?(var)

      @new_local[var] = [] if @new_local[var].nil?

      unless standalone
        @old_local[var] = [] if @old_local[var].nil?
        if @new_local[var].include?(member)
          @old_local[var].push(member) unless @old_local[var].include?(member)
        else
          @old_local[var].delete(member) if @old_local[var].include?(member)
        end
      end
      @new_local[var].push(member) unless @new_local[var].include?(member)
    end

    # Internal del
    def real_del(var, member)
      return nil unless @listed_types.include?(var)

      @new_local[var] = [] if @new_local[var].nil?

      unless standalone
        @old_local[var] = [] if @old_local[var].nil?
        if @new_local[var].include?(member)
          @old_local[var].push(member) unless @old_local[var].include?(member)
        else
          @old_local[var].delete(member) if @old_local[var].include?(member)
        end
      end
      @new_local[var].delete(member) if @new_local[var].include?(member)
    end

    # General key set
    def set(var, value)
      return nil unless @keys.include?(var)

      @old_local[var] = @new_local[var] unless standalone
      @new_local[var] = value
    end

    # General key get
    def get(var)
      return nil unless @keys.include?(var)
      return nil unless @new_local.key?(var)

      @new_local[var]
    end

    def sync_all
      @keys.each do |key|
        sync_key(key)
      end
    end

    # General key sync
    def sync_key(var)
      return nil if standalone
      return nil unless @keys.include?(var)

      if @oid.nil?
        puts "Cannot sync nil oid"
        return
      end

      kstr = key_to_string(var)
      return nil if kstr.nil?

      # Initialize data structures for listed types
      if @listed_types.key?(var)
        @new_remote[var] ||= []
        @new_local[var] ||= []
        @old_local[var] ||= []
      end

      @old_remote[var] = @new_remote[var].nil? ? nil : @new_remote[var].dup

      # Get new value from Redis
      @new_remote[var] = if @listed_types.key?(var)
                           @r.smembers(kstr)
                         else
                           @r.get(kstr)
                         end

      # Check changes and propagate
      if (!@old_remote[var].eql?(@new_remote[var])) && (!@old_local[var].eql?(@new_local[var]))
        if @new_remote[var].eql?(@new_local[var])
          @old_local[var] = @old_remote[var] = @new_remote[var]
        else
          return nil
        end
      elsif @old_remote[var].eql?(@new_remote[var]) && @old_local[var].eql?(@new_local[var])
        # No changes
      elsif @new_local[var].eql?(@old_local[var])
        # Propagating remote -> local
        @old_local[var] = @new_remote[var].nil? ? nil : @new_remote[var].dup
        @new_local[var] = @new_remote[var].nil? ? nil : @new_remote[var].dup
        @old_remote[var] = @new_remote[var].nil? ? nil : @new_remote[var].dup
      else
        # Propagating local -> remote
        @new_remote[var] = @new_local[var].nil? ? nil : @new_local[var].dup
        @old_remote[var] = @new_local[var].nil? ? nil : @new_local[var].dup
        @old_local[var] = @new_local[var].nil? ? nil : @new_local[var].dup
        
        if @listed_types.key?(var)
          @r.del(kstr) if @r.exists?(kstr)
          @new_remote[var]&.each { |member| @r.sadd(kstr, member) }
        elsif @new_remote[var].nil?
          @r.del(kstr) if @r.exists?(kstr)
        else
          @r.set(kstr, @new_remote[var])
        end
      end
      true
    end

    # Set key sync
    def sync_set(var, member)
      unless @listed_types.key?(var)
        puts "La chiave non e' un insieme"
        return nil
      end

      @new_remote[var] ||= []
      @old_remote[var] ||= []
      @new_local[var] ||= []
      @old_local[var] ||= []

      if @oid.nil?
        puts "Cannot sync nil oid"
        return
      end

      kstr = key_to_string(var)
      if kstr.nil?
        puts "Failed to create the redis key"
        return nil
      end

      # Update old_remote based on new_remote
      if @new_remote[var].include?(member) && !@old_remote[var].include?(member)
        @old_remote[var].push(member)
      elsif !@new_remote[var].include?(member) && @old_remote[var].include?(member)
        @old_remote[var].delete(member)
      end

      # Update new_remote from Redis
      if @r.exists?(kstr)
        if @r.sismember(kstr, member)
          @new_remote[var].push(member) unless @new_remote[var].include?(member)
        else
          @new_remote[var].delete(member) if @new_remote[var].include?(member)
        end
      end

      # Check modifications
      modification_local = (@old_local[var].include?(member) && !@new_local[var].include?(member)) ||
                          (!@old_local[var].include?(member) && @new_local[var].include?(member))

      modification_remote = (@old_remote[var].include?(member) && !@new_remote[var].include?(member)) ||
                           (!@old_remote[var].include?(member) && @new_remote[var].include?(member))

      modification_same = (@new_local[var].include?(member) && @new_remote[var].include?(member)) ||
                         (!@new_local[var].include?(member) && !@new_remote[var].include?(member))

      if modification_remote && modification_local
        if modification_same
          if @new_local[var].include?(member)
            @old_local[var].push(member) unless @old_local[var].include?(member)
            @old_remote[var].push(member) unless @old_remote[var].include?(member)
          else
            @old_local[var].delete(member) if @old_local[var].include?(member)
            @old_remote[var].delete(member) if @old_remote[var].include?(member)
          end
        else
          puts "Conflict. PD!"
          return nil
        end
      elsif !modification_local && !modification_remote
        # No changes
      elsif modification_remote
        # Propagating remote -> local
        if @new_remote[var].include?(member)
          @old_local[var].push(member) unless @old_local[var].include?(member)
          @old_remote[var].push(member) unless @old_remote[var].include?(member)
          @new_local[var].push(member) unless @new_local[var].include?(member)
        else
          @old_local[var].delete(member) if @old_local[var].include?(member)
          @old_remote[var].delete(member) if @old_remote[var].include?(member)
          @new_local[var].delete(member) if @new_local[var].include?(member)
        end
      else
        # Propagating local -> remote
        if @new_local[var].include?(member)
          @r.sadd(kstr, member) unless @new_remote[var].include?(member)
          @old_local[var].push(member) unless @old_local[var].include?(member)
          @old_remote[var].push(member) unless @old_remote[var].include?(member)
          @new_remote[var].push(member) unless @new_remote[var].include?(member)
        else
          @r.srem(kstr, member) if @new_remote[var].include?(member)
          @old_local[var].delete(member) if @old_local[var].include?(member)
          @old_remote[var].delete(member) if @old_remote[var].include?(member)
          @new_remote[var].delete(member) if @new_remote[var].include?(member)
        end
      end
    end

    # key string helper
    def key_to_string(key)
      return nil if @oid.nil?

      ret = "#{@prefix}:#{@oid}:#{key}"
      ret += ":#{@lang}" if @@lds.include?(key) && !@lang.nil?
      ret
    end
  end
end
