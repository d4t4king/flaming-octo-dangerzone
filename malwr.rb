#!/usr/bin/env ruby

require 'colorize'
require 'open-uri'
require 'nokogiri'
require 'mimemagic'
require 'tempfile'
require 'net/http'
require 'digest/md5'

def save_malware(response, directory)
	#url = response.url
	#data = response.content
end

def process_mdl
	urls = Array.new
	xdoc = Nokogiri::XML(open('http://www.malwaredomainlist.com/hostslist/mdl.xml'))
	xdoc.xpath('//channel/item/description').each do |item|
#ost: exkn0md6fh.qsdgi.com/azomytze3q, IP address: 5.135.230.183, ASN: 16276, Country: FR, Description: RIG EK
		if item.text =~ /Host\: (.*)\, IP .*Description: (.*)/
			dns = $1
			descr = $2
			#puts "Host: #{dns}, Descr: #{descr}".yellow
		else
			puts "No match".red
		end
		urls.push(dns)
	end
	return urls
end

source_urls = process_mdl
i = 0
#puts source_urls.inspect
source_urls.each do |url|
	file = Tempfile.new('tmp')
	begin
		Net::HTTP.start("http://#{url}") { |http|
			pn = Pathname.new(url)
			resp = http.get(pn.basename)
			r_md5 = Digest::MD5.hexdigest(resp)
			file.write(resp.body)
		}
		#open("malwr/#{url}", 'wb') do |file|
		#	file << open("http://#{url}/").read
		#end
		md5 = Digest::MD5.hexdigest(File.read(file))
		magic = MimeMagic.by_magic(File.open(file))
		puts "#{url} : #{magic}"
		puts "f:#{md5} : r:#{r_md5}"
		if i >= 20
			break
		end
		i =+ 1
	rescue Exception => e
		puts "### ERROR: #{url}".red
		puts "#{e.message}".red
		puts "#{e.backtrace}".red
	ensure
		file.close
	end
end

