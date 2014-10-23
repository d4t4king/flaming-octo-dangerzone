#!/usr/bin/env ruby

require 'colorize'
require 'open-uri'
require 'nokogiri'
require 'mimemagic'
require 'tempfile'
require 'net/http'
require 'digest/md5'
require 'rss'

def save_malware(response, directory)
	#url = response.url
	#data = response.content
end

def process_urlquery
	urls = Array.new
	xdoc = Nokogiri::HTML(open('http://urlquery.net'))
	xdoc.xpath('//table//a').each do |item|
		#puts item.to_s.magenta
		if item.to_s =~ /title\=\"(.*)\" href=/
			url = $1
			urls.push(url)
		else
			puts "No match.".red
		end
	end
	return urls
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

def process_rss_descr(_url)
	urls = Array.new
	rss = RSS::Parser.parse(_url, false)
	case rss.feed_type
		when 'rss'
			rss.items.each { |item| 
				#puts item.description 
				#Host: asd.vicentelopez.us/vbign3s2pe, IP address: 192.99.197.133, ASN: 16276, Country: CA, Description: exploit kit
				if item.description =~ /^Host: (.*?)\, IP addr.* Description\: (.*)/
					host = $1
					descr = $2
					urls.push(host)
				end
				#print "#{host}".cyan
				#print " : "
				#puts "#{descr}".magenta
			}
		when 'atom'
			rss.items.each { |item| puts item.description.content }
	end
	return urls
end

def process_simple_list(_url)
	urls = Array.new
	begin
		open(_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).each do |line|
			line.chomp!
			if line =~ /^http(s)?:\/\//
				#puts "|#{line}|".green
				urls.push(line)
			end
		end
	rescue Exception => e
		puts "#{e.message}".red
		return nil
	end
	return urls
end

def get_mal_urls
	malurls = Array.new
	_urls = process_rss_descr("http://www.malwaredomainlist.com/hostslist/mdl.xml")
	(malurls << _urls).flatten!
	_urls = process_rss_descr("http://malc0de.com/rss/")
	(malurls << _urls).flatten!
	_urls = process_simple_list("http://vxvault.siri-urz.net/URL_List.php")
	(malurls << _urls).flatten!
	_urls = process_urlquery
	(malurls << _urls).flatten!
	_urls = process_simple_list("http://malwareurls.joxeankoret.com/normal.txt")
	(malurls << _urls).flatten!
	
	return malurls
end

source_urls = get_mal_urls
i = 0
#puts source_urls.inspect.light_black
#source_urls.each do |u|
#	if i == 0 || i % 2 == 0
#		puts u.to_s.light_black
#		i += 1
#	else
#		puts u.to_s.magenta
#		i += 1
#	end
#end

#exit 0

source_urls.each do |url|
	#puts "|#{url}|".green
	puts "|#{url}|"
	file = Tempfile.new('tmp')
	begin
		#url.chomp
		if ! url =~ /http(s)?\/\//
			url = "http://#{url}"
		end
		Net::HTTP.start("#{url}") { |http|
			pn = Pathname.new(url)
			resp = http.get(pn.basename)
			r_md5 = Digest::MD5.hexdigest(resp)
			file.write(resp.body)
		}
		md5 = Digest::MD5.hexdigest(File.read(file))
		magic = MimeMagic.by_magic(File.open(file))
		puts "#{url} : #{magic}"
		puts "f:#{md5} : r:#{r_md5}"
		#if i >= 20
		#	break
		#end
		#i =+ 1
	rescue Exception => e
		#puts "### ERROR: #{url}".red
		puts "### ERROR: #{url}"
		#puts "#{e.message}".red
		puts "#{e.message}"
		#puts "#{e.backtrace}".red
	ensure
		file.close
	end
end

