#!/usr/bin/env ruby

require 'rubyfuse'
require 'mysql'
require 'redis'
require './RodoObject.rb'

r = Redis.new(:host => "127.0.0.1", :port => 6379)

#obj = RodoObject.new('Rtax','it',r)
#ret=[]			
#r.smembers('tax:all').each do |ioid|
#	puts ioid
#	obj.oid=ioid.to_i()
#	obj.sync_key(:label)
#	label=obj.get(:label)
#	ret << label.to_s()
#end 
#puts ret.to_s()

#obj = RodoObject.new('Rtax','it',r)
#ret=[]
#obj.search(:label,'ciao')
#if ! obj.oid.nil?
#        obj2 = RodoObject.new('Rtag','it',r)
#        obj.sync_key(:tags)
#        lmembers=obj.get(:tags)
#        lmembers.each do |ioid|
#                obj2.oid=ioid.to_i()
#                obj2.sync_key(:label)
#                label=obj2.get(:label)
#                ret << label.to_s()
#        end
#end
#puts ret.to_s()
