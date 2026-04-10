#!/usr/bin/env ruby

require 'rubygems'
require 'redis'


class RodoObject
	@@lds = [:label]		# the list of language dependent keys

        attr_accessor	:oid		# The id, may be nil. otherwise is a radis key id (composed from the object type)
        attr_accessor	:synced		# The synced status: 0 - async, 1 - synced
	attr_accessor	:standalone	
	attr_accessor	:useall

	#		@lang		# The object language, or nil or 'all'
	#		@r		# The redis instance, or nil
	#		@type		# The object type
	#		@prefix		# The prefix used for storing the object keys in the KV store
	#		@keys		# The actual keys hash
	#		@listed_types	# An hash that list for each key whose value is a list which is the inner object type

        def initialize(type, lang=nil, server=nil)
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
			@listed_types = { :tags => ["Rtag",:res] }
			@useall = true
                when "Rtax"
			@type = type
			@prefix = 'tax'
                        @keys = [:label, :tags]
			@listed_types = { :tags => ["Rtag",:tax] }
			@useall = true
                when "Rtag"
			@type = type
			@prefix = 'tag'
                        @keys = [:label, :tax, :res]
			@listed_types = { :tax => ["Rtax",:tags] , :res => ["Rresource",:tags] }
			@useall = true
                when "Rrule"
			@type = type
			@prefix = 'rul'
                        @keys = [:label, :rule]
			@listed_types = { }
			@useall = true
		when "Rauto"
			@type = type
			@prefix = 'aut'
                        @keys = [:label, :urlmatch, :tagset]
			@listed_types = { }
			@useall = true
		else
			raise ArgumentError, "No valid object type"
                end
        end

	# Override the class method
	def class
		return @type
	end

	# Return the list of the object keys
        def keys
                @keys
        end

	# Return the list of the object keys (unlisted)
        def unlisted_keys
		ret=[]
                @keys.each do |key|
			ret << key unless @listed_types.include?(key)	
		end
		ret
        end

	def oid=(new_oid)
		unless new_oid.is_a?(Integer)
			puts "Only integer oid"
			puts self.inspect
			return
		end

		if new_oid == 0 
			@oid=@r.incr(@prefix+':curr')
		else
			@oid = new_oid	
		end

		if ! standalone and useall
			@r.sadd(@prefix+':all',@oid)
		end
		
		@old_remote = {}
		@new_remote = {}
		@old_local = {}
		@new_local = {}
	end

	def deloid()
		if @oid.nil?
			puts "Delete is only allowed with not nil oid"
			return
		end

		if ! standalone and useall
			@r.srem(@prefix+':all',@oid)
		end

		@keys.each do |key|
			kstr = key_to_string(key)
			if @r.exists?(kstr)
				@r.del(kstr)
			end
		end

		@oid = nil	
		@old_remote = {}
		@new_remote = {}
		@old_local = {}
		@new_local = {}
	end

	# This is the global search over the useall elements, after the search the first occurrence is returned in the form of an assigned oid, if the serach fail the oid remain nil
	def search(var,value)
		if ! @oid.nil?
			puts "Search is only allowed with nil oid"
			return
		end

		if ! useall 
			puts "Search is only allowed on types with useall enabled"
			return
		end

		if @listed_types.include?(var)
			puts "Search is only allowed on unlisted types"
			return
		end

		allmembers=@r.smembers(@prefix+':all')

		allmembers.each do |ioid|
			ret = "#{@prefix}:#{ioid}:#{var.to_s}"
			if @@lds.include?(var) && !@lang.nil?
				ret += ":#{@lang}"
			end

			if @r.exists?(ret)
				ckvalue=@r.get(ret)
				if ckvalue==value
					@oid=ioid.to_i()
					break
				end
			end
		end
		@oid
	end

	# This is the inner search, it search for things within a given set
	def inner_search(search_key, var,value)
		if @oid.nil?
			puts "Search is only allowed with no nil oid"
			return nil
		end
		if !@listed_types.include?(search_key)
			puts "Search is only allowed on listed types"
			return nil
		end

		allmembers=[]

		if !@new_local[search_key].nil?
			allmembers=@new_local[search_key]
		end

		type=@listed_types[search_key][0]

		auxobj=RodoObject.new(type,@lang,@r)

		allmembers.each do |ioid|
			auxobj.oid=ioid.to_i()
			auxobj.sync_key(var)
			ckvalue=auxobj.get(var)

			if ckvalue==value
				return ioid.to_i()
			end
		end
		return nil
	end

	# Add an element to a list
	def add(var, member)
		sync_set(var, member)
		real_add(var, member)
		sync_set(var, member)
	end


	# Del an element to a list
	def del(var, member)
		sync_set(var, member)
		#puts self.inspect
		real_del(var, member)
		#puts self.inspect
		sync_set(var, member)
	end

	# Internal add
	def real_add(var, member)
		unless @listed_types.include?(var)
			return nil
		end

		@new_local[var]=[] if @new_local[var].nil?	

		if ! standalone
			@old_local[var]=[] if @old_local[var].nil?	
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
		unless @listed_types.include?(var)
			return nil
		end

		@new_local[var]=[] if @new_local[var].nil?	

		if ! standalone
			@old_local[var]=[] if @old_local[var].nil?	
			if @new_local[var].include?(member)
				@old_local[var].push(member) unless @old_local[var].include?(member)
			else
				@old_local[var].delete(member) if @old_local[var].include?(member)
			end
		end
		@new_local[var].delete(member) if @new_local[var].include?(member)
	end



	# General key set, set the key only to the local object
        def set(var, value)
		# Check if the key is among the object requested
		unless @keys.include?(var)
			# puts "An unknown key has been set"
			return nil
		end
		if ! standalone
			@old_local[var] = @new_local[var]
		end
		@new_local[var] = value
        end

	# General key get
	def get(var)
		unless @keys.include?(var)
			# puts "An unknown key has been getted"
			return nil
		end

		unless @new_local.has_key?(var)
			# puts "Key not found"
			return nil
		end

		return @new_local[var]
	end

	def sync_all()
		@keys.each do |key|
			sync_key(key)
		end
	end

	# General key sync
        def sync_key(var)
		# Check if the object is standalone
		if standalone
			return nil
		end

		# puts "Syncing \"#{var}\""
		unless @keys.include?(var)
			# puts "An unknown key has been synced"
			return nil
		end

		# Object id processing

		# if the oid is nil create a new object
		if @oid.nil?
			#@oid=@r.incr(@prefix+':curr')
			# puts "Object ID: "+@oid.to_s
			puts "Cannot sync nil oid"
			return
		end
		
		# Convert the key to a redis ready key
		kstr = key_to_string(var)
		# puts "Redis key: "+kstr.to_s

		if kstr.nil?
			# puts "Failed to create the redis key"
			return nil
		end

		##### Update the remote modification in the object remote data structures

####### Eventually start a transaction here

		if @listed_types.has_key?(var)
			if @new_remote[var] == nil
				@new_remote[var]=[]
			end
			if @new_local[var] == nil
				@new_local[var]=[]
			end
			if @old_local[var] == nil
				@old_local[var]=[]
			end
		end

		# Store the old value (from the object POV) including nil as possibility
		@old_remote[var] = (@new_remote[var].nil? ? nil : @new_remote[var].dup)

		# Get the new value from redis according to data type
		if @listed_types.has_key?(var)
			@new_remote[var] = @r.smembers(kstr)
		else
			@new_remote[var] = @r.get(kstr)
		end

		##### Check the direction of the changes and propagate
		if ( ! @old_remote[var].eql?(@new_remote[var]) ) && ( ! @old_local[var].eql?(@new_local[var]) ) 
			if @new_remote[var].eql?(@new_local[var])
				#puts "Same changes"
				@old_local[var] = @old_remote[var] = @new_remote[var]
			else
				#puts "Conflict"
				return nil
			end
		elsif ( @old_remote[var].eql?(@new_remote[var]) ) && ( @old_local[var].eql?(@new_local[var]) ) 
			 # puts "No changes"
		else
			if @new_local[var].eql?(@old_local[var])
				#puts "Propagating remote -> local"
				@old_local[var] = (@new_remote[var].nil? ? nil : @new_remote[var].dup)
				@new_local[var] = (@new_remote[var].nil? ? nil : @new_remote[var].dup)
				@old_remote[var] = (@new_remote[var].nil? ? nil : @new_remote[var].dup)
			else
				#puts "Propagating local -> remote"
				@new_remote[var] = (@new_local[var].nil? ? nil : @new_local[var].dup)
				@old_remote[var] = (@new_local[var].nil? ? nil : @new_local[var].dup)
				@old_local[var] = (@new_local[var].nil? ? nil : @new_local[var].dup)
				if @listed_types.has_key?(var)
					if @r.exists?(kstr)
						@r.del(kstr)
					end
					if @new_remote[var]
						@new_remote[var].each do |member|
							@r.sadd(kstr,member)
						end
					end
				else
					if @new_remote[var] == nil
						if @r.exists?(kstr)
							@r.del(kstr)
						end
					else
						@r.set(kstr, @new_remote[var])
					end
				end
			end
		end
		return true
	end

	# Set key sync
	def sync_set(var, member)
		unless @listed_types.has_key?(var)
			puts "La chiave non e' un insieme"
			return nil
		end

		if @new_remote[var] == nil
			@new_remote[var]=[]
		end
		if @old_remote[var] == nil
			@old_remote[var]=[]
		end
		if @new_local[var] == nil
			@new_local[var]=[]
		end
		if @old_local[var] == nil
			@old_local[var]=[]
		end
	
		
		# if the oid is nil create a new object
		if @oid.nil?
			#@oid=@r.incr(@prefix+':curr')
			# puts "Object ID: "+@oid.to_s
			puts "Cannot sync nil oid"
			return
		end
		
		# Convert the key to a redis ready key
		kstr = key_to_string(var)

		if kstr.nil?
			puts "Failed to create the redis key"
			return nil
		end

		# Store the old value (from the object POV) including nil as possibility
		if @new_remote[var].include?(member) && !@old_remote[var].include?(member)
			@old_remote[var].push(member)
		elsif !@new_remote[var].include?(member) && @old_remote[var].include?(member)
			@old_remote[var].delete(member)
		end
		
		if @r.exists?(kstr)
			if @r.sismember(kstr, member)
		 		@new_remote[var].push(member) if !@new_remote[var].include?(member)
			else
				@new_remote[var].delete(member) if @new_remote[var].include?(member)
			end
		end
		
		##### Check the direction of the changes and propagate
		modification_local = (@old_local[var].include?(member) && !@new_local[var].include?(member)) || 
				     (!@old_local[var].include?(member) && @new_local[var].include?(member))
		
		modification_remote = (@old_remote[var].include?(member) && !@new_remote[var].include?(member)) || 
				     (!@old_remote[var].include?(member) && @new_remote[var].include?(member))

		modification_same = (@new_local[var].include?(member) && @new_remote[var].include?(member)) || 
				     (!@new_local[var].include?(member) && !@new_remote[var].include?(member))


		if ( modification_remote && modification_local ) 
			if modification_same
				#puts "Same changes"
				if @new_local[var].include?(member)
					@old_local[var].push(member) if !@old_local[var].include?(member)
					@old_remote[var].push(member) if !@old_remote[var].include?(member)
				else
					@old_local[var].delete(member) if @old_local[var].include?(member)
					@old_remote[var].delete(member) if @old_remote[var].include?(member)
				end

			else
				puts "Conflict. PD!"
				return nil
			end
		elsif ( !modification_local && !modification_remote ) 
			 #puts "No changes"
		else
			if modification_remote
				#puts "Propagating remote -> local"
				if @new_remote[var].include?(member)
					@old_local[var].push(member) if !@old_local[var].include?(member)
					@old_remote[var].push(member) if !@old_remote[var].include?(member)
					@new_local[var].push(member) if !@new_local[var].include?(member)
				else
					@old_local[var].delete(member) if @old_local[var].include?(member)
					@old_remote[var].delete(member) if @old_remote[var].include?(member)
					@new_local[var].delete(member) if @new_local[var].include?(member)
				end
			else
				#puts "Propagating local -> remote"
				if @new_local[var].include?(member)
					if !@new_remote[var].include?(member)
						@r.sadd(kstr, member)
					end
					@old_local[var].push(member) if !@old_local[var].include?(member)
					@old_remote[var].push(member) if !@old_remote[var].include?(member)
					@new_remote[var].push(member) if !@new_remote[var].include?(member)
				else
					if @new_remote[var].include?(member)
						@r.srem(kstr, member)
					end
					@old_local[var].delete(member) if @old_local[var].include?(member)
					@old_remote[var].delete(member) if @old_remote[var].include?(member)
					@new_remote[var].delete(member) if @new_remote[var].include?(member)
				end
			end
		end
	

	end

	# key string helper
	def key_to_string(key)
		return nil if @oid.nil?
		ret = "#{@prefix}:#{@oid}:#{key.to_s}"
		if @@lds.include?(key) && !@lang.nil?
			ret += ":#{@lang}"
		end
		ret
	end

end
