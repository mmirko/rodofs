#!/usr/bin/env ruby
#

require 'rubygems'
require 'redis'
require './RodoObject.rb'
require 'pp'

obj = nil

##########################################################

#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj = RodoObject.new('Rresource','it',r)
#rescue ArgumentError
#	print "Object error"
#end

#obj.oid=2
#obj.set(:label,'ciao')
#obj.sync_key(:label)
#puts obj.get(:label)

##########################################################

#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj = RodoObject.new('Rtax','it',r)
#rescue ArgumentError
#	print "Object error"
#end
#
#obj.oid=0
#obj.set(:label,'ciao')
#obj.sync_key(:label)

##########################################################

#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj = RodoObject.new('Rtag','it',r)
#rescue ArgumentError
#	print "Object error"
#end

#obj.oid=0
#obj.set(:label,'tag1onciao')
#obj.add(:tax,'1')
#obj.sync_all()

##########################################################

#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj = RodoObject.new('Rtax','it',r)
#rescue ArgumentError
#	print "Object error"
#end

#obj.search(:label,'ciao')
#puts obj.oid.nil?
#puts obj.oid

##########################################################

#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj = RodoObject.new('Rtax','it',r)
#rescue ArgumentError
#	print "Object error"
#end

#obj.oid=0
#obj.set(:label,'ciao')
#obj.sync_key(:label)
#puts obj.oid.to_s()
#obj.deloid()

##########################################################
#begin
#	r = Redis.new(:host => "127.0.0.1", :port => 6379)
#	obj1 = RodoObject.new('Rtax','it',r)
#	obj2 = RodoObject.new('Rtag','it',r)
#rescue ArgumentError
#	print "Object error"
#end
#
#obj1.oid=1
#obj1.set(:label,'ciao1')
#obj1.add(:tags,'1')
#obj1.add(:tags,'2')
#obj1.sync_all()
#
#obj2.oid=1
#obj2.set(:label,'tag1')
#obj2.add(:tax,'1')
#obj2.sync_all()
#
#obj2.oid=2
#obj2.set(:label,'tag2')
#obj2.add(:tax,'1')
#obj2.sync_all()
#
#puts obj1.inner_search(:tags,:label,'ciao1').nil?

##########################################################
begin
	r = Redis.new(:host => "127.0.0.1", :port => 6379)
	obj = RodoObject.new('Rresource','it',r)
rescue ArgumentError
	print "Object error"
end

puts obj.unlisted_keys.to_s()

##########################################################

