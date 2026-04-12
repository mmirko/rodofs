# frozen_string_literal: true

require 'rfusefs'
require 'redis'
require_relative 'rodo_object'

module RodoFS
  # FuseDir implements the FUSE filesystem for RodoFS
  class FuseDir < ::FuseFS::FuseDir
    private

    def scan_path(path)
      path.split('/').reject(&:empty?)
    end

    public

        def initialize(lang=nil, server=nil)

                @lang = lang
                @r = server

		@debug=false

		@rule=nil
		@currmatch=[]

		@rules={}

		@errorlist=[]

		# Loading the rules and computing the members
		obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
		@r.smembers('rul:all').each do |ioid|
			obj.oid=ioid.to_i()
			obj.sync_all()
			label=obj.get(:label)
			rule=obj.get(:rule)
			rmemb=compute_rule_members(rule)
			if rmemb.nil?
				@errorlist.push('Main rule failed')
				rmemb=[]
			end
			@rules[label]=[rule,rmemb]
		end 
	end

	def check_rule_member(rule,member_oid)
		# Check if a member match a given rule
		case
		when rule == 'none'
		when rule =~ /^([\w\s]+)=([\w\s]+)$/
			taxname,tagname=rule.split('=')

			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,taxname)
			if !obj.oid.nil?
				obj.sync_key(:tags)
				resoid2=obj.inner_search(:tags,:label,tagname)
				if !resoid2.nil?
					obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
					obj2.oid=resoid2
					obj2.sync_key(:res)
					rmembers=obj2.get(:res)
					if !rmembers.nil?
						return rmembers.include?(member_oid.to_s)
					end
				end
			end
		end
		return false
	end

	def compute_rule_members(rule)
		# Compute the members of a rule
		ret=[]
		case
		when rule == 'none'
		when rule =~ /^([\w\s]+)=([\w\s]+)$/
			taxname,tagname=rule.split('=')

			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,taxname)
			if !obj.oid.nil?
				obj.sync_key(:tags)
				resoid2=obj.inner_search(:tags,:label,tagname)
				if !resoid2.nil?
					obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
					obj2.oid=resoid2
					obj2.sync_key(:res)
					rmembers=obj2.get(:res)
					if !rmembers.nil?
						rmembers.each do |ioid|
							ret << ioid unless ret.include?(ioid)
						end
					end
				end
			end
		when rule =~ /^([\w\s]+)!=([\w\s]+)$/
			taxname,tagname=rule.split('!=')

			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,taxname)
			if !obj.oid.nil?
				obj.sync_key(:tags)
				resoid2=obj.inner_search(:tags,:label,tagname)
				if !resoid2.nil?
					rmembers=@r.sdiff('res:all','tag:'+resoid2.to_s+':res')
					if !rmembers.nil?
						rmembers.each do |ioid|
							ret << ioid unless ret.include?(ioid)
						end
					end
				end
			end
		else
			return nil
		end
		return ret
	end

#####

	def directory?(path)
		scanned = scan_path(path)
		puts "directory?("+path+")" unless !@debug
		case
		# Root dir
		when scanned[0].nil?
			true # This means "/"
		# Main dir
		when ['tax','rules','res','auto'].include?(scanned[0]) && scanned[1].nil?
			return true
		# Tax dir
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			return !obj.oid.nil? ? true : false
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			if ! obj.oid.nil?
				obj.sync_key(:tags)
				resoid=obj.inner_search(:tags,:label,scanned[2])
				return !resoid.nil? ? true : false
			else
				return false
			end
		# Rules dir
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			return @rules.keys.include?(scanned[1]) ? true : false
		else
			return false
		end
	end

	def file?(path)
		scanned = scan_path(path)
		puts "file?("+path+")" unless !@debug
		case
		when scanned[0].nil?
			return false
		when ['ctl'].include?(scanned[0])
			return true
		# Auto
		when scanned[0]=='auto' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rauto',@lang,@r)
			resoid=obj.search(:label,scanned[1])
			return !resoid.nil? ? true : false
		# Res
		when scanned[0]=='res' && !scanned[1].nil? && scanned[2].nil?
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)

			# Each current matched entries are searched for the file
			@currmatch.each do |ioid|
				obj3.oid=ioid.to_i
				obj3.sync_key(:label)
				if obj3.get(:label) == scanned[1]
					return true
				end
			end
			return false
		# Tax
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			# Search the taxonomy
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			if ! obj.oid.nil?
				# Search within the tags the given one
				obj.sync_key(:tags)
				resoid=obj.inner_search(:tags,:label,scanned[2])
				if ! resoid.nil?
					obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
					obj2.oid=resoid
					obj2.sync_key(:res)
					resoid2=obj2.inner_search(:res,:label,scanned[3])
					# If the given resource is among the tags resources it exists
					return !resoid2.nil? ? true : false
				else
					return false
				end
			else
				return false
			end
		when scanned[0]=='rules' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			if @rules.keys.include?(scanned[1])
				if scanned[2]=='ctl'
					return true
				end
				obj = RodoFS::RodoObject.new('Rresource',@lang,@r)
				@rules[scanned[1]][1].each do |ioid|
					obj.oid=ioid.to_i()
					obj.sync_key(:label)
					label=obj.get(:label)
					if label==scanned[2]
						return true
					end
				end
			end
		else
			return false
		end
	end

#####

	def mkdir(path)
		scanned = scan_path(path)
		puts "mkdir("+path+")" unless !@debug
		case
		# Taxonomies
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.oid=0
			obj.set(:label,scanned[1])
			obj.sync_key(:label)
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj2.oid=0
			obj2.set(:label,scanned[2])
			obj2.add(:tax,obj.oid.to_s())
			obj2.sync_all()
			obj.add(:tags,obj2.oid.to_s())
			obj.sync_all()
		# Rules
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
			obj.oid=0
			obj.set(:label,scanned[1])
			obj.set(:rule,'none')
			obj.sync_all()

			rmemb=compute_rule_members('none')
			if rmemb.nil?
				@errorlist.push('rule '+scanned[1]+' failed')
				rmemb=[]
			end
			@rules[scanned[1]]=['none',rmemb]
		end
	end

	def can_mkdir?(path)
		scanned = scan_path(path)
		puts "can_mkdir?("+path+")" unless !@debug
		case
		# Taxonomies
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			return obj.oid.nil? ? true : false
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			if !obj.oid.nil?
				obj.sync_key(:tags)
				resoid=obj.inner_search(:tags,:label,scanned[2])
				return resoid.nil? ? true : false
			else
				return false
			end
		# Rules
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
			obj.search(:label,scanned[1])
			return obj.oid.nil? ? true : false
		# Every other thing is crap
		else
			return false
		end
	end

#####

	def rmdir(path)
		scanned = scan_path(path)
		puts "rmdir("+path+")" unless !@debug
		case
		# Taxonomies
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			obj.deloid()
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			obj.sync_all()
			resoid=obj.inner_search(:tags,:label,scanned[2])
			obj.del(:tags,resoid.to_s())
			obj.sync_all()
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj2.oid=resoid
			obj2.deloid()
		# Rules
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
			obj.search(:label,scanned[1])
			obj.deloid()
			@rules.delete(scanned[1])
			#puts @rules.inspect
		end
	end

	def can_rmdir?(path)
		scanned = scan_path(path)
		puts "can_rmdir?("+path+")" unless !@debug
		case
		# Taxonomies
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj.search(:label,scanned[1])
			if !obj.oid.nil?
				obj.sync_key(:tags)
				ressub=obj.get(:tags)
				return ressub.nil? || ressub==[] ? true : false
				
			end
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj1.search(:label,scanned[1])
			if !obj1.oid.nil?
				obj1.sync_key(:tags)
				resoid2=obj1.inner_search(:tags,:label,scanned[2])
				if !resoid2.nil?
					obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
					obj2.oid=resoid2.to_i()
					obj2.sync_key(:res)
					ressub=obj2.get(:res)
					return ressub.nil? || ressub==[] ? true : false
				else
					return false
				end
			else
				return false
			end
		# Rules
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
			obj.search(:label,scanned[1])
			return !obj.oid.nil? ? true : false
		# Every other thing is crap
		else
			return false
		end
	end
#####

	def xattr(path)
		return {}
	end

#####

	def rename(from_path,to_path)
		scanned_from = scan_path(from_path)
		scanned_to = scan_path(to_path)
		puts "rename("+from_path+to_path+")" unless !@debug
		case
		when scanned_from[0]=='tax' && !scanned_from[1].nil? && scanned_from[2].nil? && scanned_to[0]=='tax' && !scanned_to[1].nil? && scanned_to[2].nil?
			# Renaming a taxonomy
			if !directory?(to_path)
				obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
				obj.search(:label,scanned_from[1])
				if !obj.oid.nil?
					obj.sync_key(:label)
					obj.set(:label,scanned_to[1])
					obj.sync_key(:label)
					return true
				end
			end
		when scanned_from[0]=='tax' && !scanned_from[1].nil? && !scanned_from[2].nil? && scanned_from[3].nil? && scanned_to[0]=='tax' && !scanned_to[1].nil? && !scanned_to[2].nil? && scanned_to[3].nil?
			# Renaming a tag
			if scanned_from[1] == scanned_to[1]
				if !directory?(to_path)
					obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
					obj.search(:label,scanned_from[1])
					if !obj.oid.nil?
						obj.sync_key(:tags)
						resoid2=obj.inner_search(:tags,:label,scanned_from[2])

						if !resoid2.nil?
							obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
							obj2.oid=resoid2
							obj2.sync_key(:label)
							obj2.set(:label,scanned_to[2])
							obj2.sync_key(:label)
							return true
						end
					end
				end
			end
		end
		return false
	end

	def delete(path)
		scanned = scan_path(path)
		puts "delete("+path+")" unless !@debug
		case
		when scanned[0]=='auto' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rauto',@lang,@r)
			obj.search(:label,scanned[1])
			if !obj.oid.nil?
				obj.deloid()
			end

		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)

			obj1.search(:label,scanned[1])
			if !obj1.oid.nil?
				obj1.sync_key(:tags)
				resoid2=obj1.inner_search(:tags,:label,scanned[2])

				if !resoid2.nil?
					obj2.oid=resoid2
					obj2.sync_key(:res)
					resoid3=obj2.inner_search(:res,:label,scanned[3])

					if !resoid3.nil?
						obj3.oid=resoid3
						obj3.sync_key(:tags)
						obj3.del(:tags,obj2.oid.to_s())
						obj3.sync_all()

						obj2.del(:res,obj3.oid.to_s())
						obj2.sync_key(:res)

						# If the resource is not tagged anywhere remove it
						if obj3.get(:tags).nil? or obj3.get(:tags).empty?
							md5=obj3.get(:md5)
							if !md5.nil?
								if @r.exists?('md5:'+md5+':oid')
									@r.del('md5:'+md5+':oid')
								end
							end
							obj3.deloid()
						end
					end
				end
			end

		end
	end

	def can_delete?(path)
		# The only files that may be delete are the files from a tag directory
		scanned = scan_path(path)
		puts "can_delete?("+path+")" unless !@debug
		case
		when scanned[0]=='auto' && !scanned[1].nil? && scanned[2].nil?
			return file?(path)
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			return file?(path)
		else
			return false
		end
	end

#####

	def can_write?(path)
		scanned = scan_path(path)
		puts "can_write?("+path+")" unless !@debug
		case
		when scanned[0].nil?
			return false
		when ['ctl'].include?(scanned[0])
			return true
		when scanned[0]=='auto'  && !scanned[1].nil? && scanned[2].nil?
			return true
		when scanned[0]=='res'  && !scanned[1].nil? && scanned[2].nil?
			# All the files in res may be written
			return file?(path)
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			if directory?('/'+scanned[0]+'/'+scanned[1]+'/'+scanned[2])
				return true
			else
				return false
			end
		when scanned[0]=='rules' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			if @rules.keys.include?(scanned[1])
				if scanned[2]=='ctl'
					return true
				end
			end
		else
			return false
		end
	end

	def write_to(path,body)
	# Since this is only called after can_write?(), we assume
	# Valid fields.
		scanned = scan_path(path)
		puts "write_to("+path+")" unless !@debug
		case
		when scanned[0]=='ctl'
			body.split(/\n/).each do |line|
				case
				when line =~ /^clearerrors$/
					@errorlist=[]
				when line =~ /^rule: (.*)$/
					proctext=line
					proctext=proctext.gsub(/^rule: (.*)$/,'\1')
					@rule=proctext

					rmemb=compute_rule_members(proctext)
					if rmemb.nil?
						@errorlist.push('Rule '+proctext+' failed')
						rmemb=[]
					end

					@currmatch=rmemb
				when line =~ /^md5: (.*)$/
					proctext=line
					proctext=proctext.gsub(/^md5: (.*)$/,'\1')

					if @r.exists?('md5:'+proctext+':oid')
						md5=@r.get('md5:'+proctext+':oid')
						@currmatch=[md5]
					else
						@errorlist.push('MD5 '+proctext+' not found')
						@currmatch=[]
					end
				end
			end
		when scanned[0]=='auto'  && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rauto',@lang,@r)
			woid=obj.search(:label,scanned[1])

			if woid.nil?
				obj.oid=0
			end
			key_to_go={}

			body.split(/\n/).each do |line|
				obj.unlisted_keys.each do |key|
					if key!=:label
						case
						when line =~ /^#{key.to_s}: (.*)$/
							proctext=line
							proctext=proctext.gsub(/^#{key.to_s}: (.*)$/,'\1')
							key_to_go[key]=proctext
						end
					end
				end
			end

			obj.sync_all()
			obj.set(:label,scanned[1])
			key_to_go.each do |key,proctext|
				obj.set(key,proctext)
			end
			obj.sync_all()


		when scanned[0]=='res'  && !scanned[1].nil? && scanned[2].nil?
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)

			# Each current matched entries are searched for the file to write to (It has to exist, eventually more than one)
			@currmatch.each do |ioid|
				obj3.oid=ioid.to_i
				obj3.sync_key(:label)
				if obj3.get(:label) == scanned[1]
					obj3.sync_all()
					break
				end
			end

			if body=='kill' || body=="kill\n"
				obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
				lmembers=obj3.get(:tags)
				lmembers.each do |ioid|
					obj2.oid=ioid.to_i
					obj2.sync_key(:res)
					obj2.del(:res,obj3.oid.to_s())
					obj2.sync_key(:res)
				end
				md5=obj3.get(:md5)
				if !md5.nil?
					if @r.exists?('md5:'+md5+':oid')
						@r.del('md5:'+md5+':oid')
					end
				end
				obj3.deloid()
			else

				# Prepare an hash with all the mathed variation (except :label and oid)
				key_to_go={}

				body.split(/\n/).each do |line|
					obj3.unlisted_keys.each do |key|
						if key!=:label
							case
							when line =~ /^#{key.to_s}: (.*)$/
								proctext=line
								proctext=proctext.gsub(/^#{key.to_s}: (.*)$/,'\1')
								key_to_go[key]=proctext
							end
						end
					end
				end

				# Commit the changes to redis
				key_to_go.each do |key,proctext|
					obj3.set(key,proctext)
					if key==:md5
						@r.set('md5:'+proctext+':oid',woid.to_s)
					end
				end
				obj3.sync_all()
			end

		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)

			obj1.search(:label,scanned[1])
			obj1.sync_key(:tags)
			resoid=obj1.inner_search(:tags,:label,scanned[2])
			obj2.oid=resoid
			obj2.sync_key(:res)
			lmembers=obj2.get(:res)

			woid=0
			if !lmembers.nil?
				resoid2=obj2.inner_search(:res,:label,scanned[3])
				if !resoid2.nil?
					woid=resoid2
				end
			end

			key_to_go={}

			body.split(/\n/).each do |line|
				obj3.unlisted_keys.each do |key|
					if key!=:label
						case
						when line =~ /^oid: (.*)$/
							if woid==0
								proctext=line
								proctext=proctext.gsub(/^oid: (.*)$/,'\1')
								woid=proctext.to_i()
							end
						when line =~ /^#{key.to_s}: (.*)$/
							proctext=line
							proctext=proctext.gsub(/^#{key.to_s}: (.*)$/,'\1')
							key_to_go[key]=proctext
						end
					end
				end
			end

			obj3.oid=woid
			obj3.sync_all()
			obj3.set(:label,scanned[3])
			key_to_go.each do |key,proctext|
				obj3.set(key,proctext)
				if key==:md5
					@r.set('md5:'+proctext+':oid',obj3.oid.to_s)
				end
			end
			obj3.add(:tags,obj2.oid.to_s())
			obj3.sync_all()

			obj2.add(:res,obj3.oid.to_s())
			obj2.sync_key(:res)

			#### Updating rule
			if check_rule_member(@rule,woid)
				@currmatch.push(woid) unless @currmatch.include?(woid)
			end
			@rules.keys.each do |rlabel|
				crule=@rules[rlabel][0]
				if check_rule_member(crule,woid)
					@rules[rlabel][1].push(woid) unless @rules[rlabel][1].include?(woid)
				end
			end


		when scanned[0]=='rules' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			case 
			when scanned[2]=='ctl'
				body.split(/\n/).each do |line|
					case
					when line =~ /^rule: (.*)$/
						obj = RodoFS::RodoObject.new('Rrule',@lang,@r)
						obj.search(:label,scanned[1])
						obj.sync_all()
						proctext=line
						proctext=proctext.gsub(/^rule: (.*)$/,'\1')

						rmemb=compute_rule_members(proctext)
						if rmemb.nil?
							@errorlist.push('Rule '+scanned[1]+' failed')
							rmemb=[]
						end

						@rules[scanned[1]]=[proctext,rmemb]
						obj.set(:rule,proctext)
						obj.sync_all()
						#puts @rules.inspect
					end
				end
			end
		end
	end

#####

	def size(path)
		puts "size("+path+")" unless !@debug
		read_file(path).length
	end

	def read_file(path)
	# Again, as this is only called after file?, assume valid fields.
		scanned = scan_path(path)
		puts "read_file("+path+")" unless !@debug
		ret=''
		case
		when scanned[0]=='ctl'
			ret=ret+'rule: '+@rule.to_s()+"\n" unless @rule.nil?

			if !@errorlist.empty?
				ret=ret+'errors: '+"\n"
				@errorlist.each do |errorl|
					ret=ret+"\t"+errorl+"\n"
				end
			end
		when scanned[0]=='auto'  && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rauto',@lang,@r)
			obj.search(:label,scanned[1])
			if !obj.oid.nil?
				obj.sync_all()
				obj.unlisted_keys.each do |key|
					if key!=:label
						value=obj.get(key)
						ret=ret+key.to_s()+': '+value.to_s()+"\n" unless value.nil?
					end
				end
			end

		when scanned[0]=='res'  && !scanned[1].nil? && scanned[2].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)
			obj3.search(:label,scanned[1])
			if !obj3.nil?
				obj3.sync_all()
				ret=ret+'oid: '+obj3.oid.to_s+"\n"
				rmembers=obj3.get(:tags)
				if !rmembers.nil?
					ret=ret+'tags: '
					rmembers.each do |ioid|
						obj2.oid=ioid.to_i()
						obj2.sync_key(:label)
						obj2.sync_key(:tax)
						tmembers=obj2.get(:tax)
						if !tmembers.nil?
							tmembers.each do |toid|
								obj1.oid=toid.to_i()
								obj1.sync_key(:label)
								ret=ret+' '+obj1.get(:label)+'='+obj2.get(:label)
							end
						end
					end
					ret=ret+"\n"
				end
				obj3.unlisted_keys.each do |key|
					if key!=:label
						value=obj3.get(key)
						ret=ret+key.to_s()+': '+obj3.get(key).to_s()+"\n" unless value.nil?
					end
				end
			end
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && !scanned[3].nil? && scanned[4].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)
			obj1.search(:label,scanned[1])
			puts obj1.inspect unless !@debug
			obj1.sync_key(:tags)
			resoid2=obj1.inner_search(:tags,:label,scanned[2])
			obj2.oid=resoid2
			puts obj2.inspect unless !@debug
			obj2.sync_key(:res)
			resoid3=obj2.inner_search(:res,:label,scanned[3])
			obj3.oid=resoid3
			puts obj3.inspect unless !@debug
			obj3.sync_all()
			ret=ret+'oid: '+resoid3.to_s+"\n"
			rmembers=obj3.get(:tags)
			if !rmembers.nil?
				ret=ret+'tags:'
				rmembers.each do |ioid|
					obj2.oid=ioid.to_i()
					obj2.sync_key(:label)
					obj2.sync_key(:tax)
					tmembers=obj2.get(:tax)
					if !tmembers.nil?
						tmembers.each do |toid|
							obj1.oid=toid.to_i()
							obj1.sync_key(:label)
							ret=ret+' '+obj1.get(:label)+'='+obj2.get(:label)
						end
					end
				end
				ret=ret+"\n"
			end
			obj3.unlisted_keys.each do |key|
				if key!=:label
					value=obj3.get(key)
					ret=ret+key.to_s()+': '+obj3.get(key).to_s()+"\n" unless value.nil?
				end
			end


		when scanned[0]=='rules' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			case 
			when scanned[2]=='ctl'
				ret=ret+'rule: '+@rules[scanned[1]][0].to_s()+"\n"
			end
		end
		ret
	end

#####

	def contents(path)
	# since this is only called when directory? is true,
	# We'll assume valid entries.
		scanned = scan_path(path)
		puts "content("+path+")" unless !@debug
		case
		when scanned[0].nil?
			ret=['ctl','tax','res','rules','auto']
		# auto dir
		when scanned[0]=='auto' && scanned[1].nil?
			obj = RodoFS::RodoObject.new('Rauto',@lang,@r)
			lmembers=@r.smembers('aut:all')
			ret=[]
			lmembers.each do |ioid|
				obj.oid=ioid.to_i()
				obj.sync_key(:label)
				label=obj.get(:label)
				ret << label.to_s()
			end 
			ret
		# res dir
		when scanned[0]=='res' && scanned[1].nil?
			obj = RodoFS::RodoObject.new('Rresource',@lang,@r)
			ret=[]
			@currmatch.each do |ioid|
				obj.oid=ioid.to_i()
				obj.sync_key(:label)
				label=obj.get(:label)
				ret << label.to_s()
			end 
			ret
		# Tax dir
		when scanned[0]=='tax' && scanned[1].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			ret=[]
			@r.smembers('tax:all').each do |ioid|
				obj.oid=ioid.to_i()
				obj.sync_key(:label)
				label=obj.get(:label)
				ret << label.to_s()
			end 
			ret
		when scanned[0]=='tax' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rtax',@lang,@r)
			ret=[]
			obj.search(:label,scanned[1])
			if ! obj.oid.nil?
				obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
				obj.sync_key(:tags)
				lmembers=obj.get(:tags)
				lmembers.each do |ioid|
					obj2.oid=ioid.to_i()
					obj2.sync_key(:label)
					label=obj2.get(:label)
					ret << label.to_s()
				end
			end
			ret
		when scanned[0]=='tax' && !scanned[1].nil? && !scanned[2].nil? && scanned[3].nil?
			obj1 = RodoFS::RodoObject.new('Rtax',@lang,@r)
			obj2 = RodoFS::RodoObject.new('Rtag',@lang,@r)
			obj3 = RodoFS::RodoObject.new('Rresource',@lang,@r)
			ret=[]
			obj1.search(:label,scanned[1])
			obj1.sync_key(:tags)
			resoid=obj1.inner_search(:tags,:label,scanned[2])
			obj2.oid=resoid
			obj2.sync_key(:res)
			lmembers=obj2.get(:res)
			lmembers.each do |ioid|
				obj3.oid=ioid.to_i()
				obj3.sync_key(:label)
				label=obj3.get(:label)
				ret << label.to_s()
			end
			ret
		# rules dir
		when scanned[0]=='rules' && scanned[1].nil?
			ret=[]			
			@rules.each do |label, other|
				ret << label.to_s()
			end 
			ret
		when scanned[0]=='rules' && !scanned[1].nil? && scanned[2].nil?
			obj = RodoFS::RodoObject.new('Rresource',@lang,@r)
			ret=['ctl']
			@rules[scanned[1]][1].each do |ioid|
				obj.oid=ioid.to_i()
				obj.sync_key(:label)
				label=obj.get(:label)
				ret << label.to_s()
			end
			ret
		end
	end
  end
end
