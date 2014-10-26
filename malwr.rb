#!/usr/bin/env ruby

require 'colorize'
require 'net/http'
require 'net/https'
require 'getoptlong'
require 'logger'
require 'configparser'
require 'open-uri'
require 'nokogiri'
require 'rss'
require 'digest/md5'
require 'fileutils'

def help
	puts <<-EOF
malwr.rb [-p|--proxy <host:port>] [-d|--dumpdir <dumpdir>] [-l|--logfile <logfile>] [-h|--help] [-D|--debug]

-p|--proxy		Specifies a proxy to use.
-d|--dumpdir	Specifies where to save the samples.
-l|--logfile	Specifies the name of the logfile to use.
-D|--debug		Enables debugging output (very verbose)

	EOF
	exit 0
end

# save the file downloaded in the HTTP response
def save_malware
end

# get a list of urls from RSS XML description
def process_rss_descr(_url)
	urls = Array.new
	rss = RSS::Parser.parse(_url, false)
	case rss.feed_type
		when 'rss'
			rss.items.each { |item|
				if item.description =~ /^Host: (.*?)\, IP addr.* Description\: (.*)/
					host = $1
					descr = $2
					urls.push(host)
				end
			}
		when 'atom'
			rss.items.each { |item| puts item.description.content }
	end
	return urls
end

# get a list of urls from RSS XML title

# get a lit of urls from a simple text list
def process_simple_list(_url)
	urls = Array.new
	begin
		open(_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).each do |line|
			line.chomp!
			if line =~ /^http(s)?:\/\//
				urls.push(line)
			end
		end
	rescue StandardError => e
		puts "#{e.message}".red
		return nil
	end
	return urls
end

# get a list of urls from urlquery.net
def process_urlquery
	urls = Array.new
	xdoc = Nokogiri::HTML(open('http://urlquery.net'))
	xdoc.xpath('//table//a').each do |item|
		if item.to_s =~ /title\=\"(.*)\" href=/
			url = $1
			urls.push(url)
		else
			print "No match.".red
			puts item.to_s.light_red
		end
	end
	return urls
end

### Main ###

# process arguments
@debug = false
opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--proxy', '-p', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--dumpdir', '-d', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--logfile', '-l', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--debug', '-D', GetoptLong::NO_ARGUMENT ]
)
opts.each do |opt, arg|
	case opt
		when '--proxy'
			@proxy = arg.to_s
		when '--dumpdir'
			@dumpdir = arg.to_s
		when '--logfile'
			@logfile = arg.to_s
		when '--help'
			help
		when '--debug'
			@debug = true
	end
end

# process config options
cfg = ConfigParser.new("malwr.conf")
if ! defined?(@proxy) || @proxy == "" || @proxy.nil?
	@proxy = cfg['proxy']
end
if ! defined?(@dumpdir) || @dumpdir == "" || @dumpdir.nil?
	@dumpdir = cfg['dumpdir']
	if ! File.directory?(@dumpdir) || Dir.exist?(@dumpdir)
		FileUtils.mkdir_p(@dumpdir)
	end
end
if ! defined?(@logfile) || @logfile == "" || @logfile.nil?
	@logfile = cfg['logfile']
end
if ! defined?(@debug) || @debug == "" || @debug.nil?
	@debug = cfg['debug']
end

puts "Debug: #{@debug}"
# options and config parsed
# set up the logger
log = Logger.new(File.open(@logfile, File::WRONLY | File::CREAT))
if @debug
	log.level = Logger::DEBUG
else 
	log.level = Logger::INFO
end

log.debug("Options and config parsing complete.")
log.debug("Logger set up complete.")
log.debug("Proxy settings: #{@proxy}")
if @proxy
	pxhost, pxport = @proxy.split(/:/)
end
log.debug("Samples saved to: #{@dumpdir}")
log.debug("Logfile written to: #{@logfile}")
if @debug
	log.debug("Debugging enabled.")
else
	log.info("Debugging disabled.")
end

# process source urls
puts "Processing source URLs"
log.info("Processing source URLs.")
malware_urls = Array.new
begin
	log.debug("Collecting urls from www.malwarecomainlist.com.")
	process_rss_descr("http://www.malwaredomainlist.com/hostslist/mdl.xml").each do |u|
		malware_urls.push(u)
	end
	log.debug("Done.")
	log.debug("Collecting urls from malc0de.com.")
	process_rss_descr("http://malc0de.com/rss/").each do |u|
		malware_urls.push(u)
	end
	log.debug("Done.")
	#log.debug("Collecting urls from vxvault.siri-urz.net.")
	#process_simple_list("http://vxvault.siri-urz.net/URL_List.php").each do |u|
	#	maleware_urls.push(u)
	#end
	#log.debug("Done.")
	log.debug("Collectin urls from malwareurls.joxeankoret.com.")
	process_simple_list("http://malwareurls.joxeankoret.com/normal.txt").each do |u|
		malware_urls.push(u)
	end
	log.debug("Done.")
	log.debug("Collecting urls from iurlquery.net.")
	process_urlquery.each do |u|
		malware_urls.push(u)
	end
	log.debug("Done.")
	#log.debug("Collecting urls from support.clean-mx.de.")
	#process_rss_title("http://support.clean-mx.de/clean-mx/rss?scope=viruses&limit=0%2C64").each do |u|
	#	malware_urls.push(u)
	#end
	#log.debug("Done.")
rescue StandardError => e
	puts "#{e.message}".red
end
log.info("Done collecting URLs from sources.")

if @debug
	puts "Got #{malware_urls.length} urls."
	#puts malware_urls.inspect
end

# download samples
log.debug("Start sample collection.")
i = 0
malware_urls.each do |u|
	puts u
	#file = Tempfile.new('tmp')
	if u !~ /^http(?:s)?:\/\//
		u = "http://#{u}"
	end
	if u =~ /^http(?:s)?:\/\/(.*?)(\/.*)/
		host = $1
		rest = $2
		log.debug("Host: #{host}, REST: #{rest}")
	else 
		puts "Couldn't match host in URL: #{u}".red
		next
	end
	begin
		if @proxy
			Net::HTTP.start(host, pxhost, pxport, { :open_timeout => 10, :read_timeout => 10 }) { |http|
				resp = http.get(rest)
				#bn = rest.split(/\//).last
				md5 = Digest::MD5.new
				md5.update(resp.body)
				open("#{@dumpdir}/#{md5.hexdigest}", "wb") do |file|
					file.write(resp.body)
				end
			}
		else 
			Net::HTTP.start(host, { :open_timeout => 10, :read_timeout => 10 }) { |http|
				resp = http.get(rest)
				#bn = rest.split(/\//).last
				md5 = Digest::MD5.new
				md5.update(resp.body)
				open("#{@dumpdir}/#{md5.hexdigest}", "wb") do |file|
					file.write(resp.body)
				end
			}
		end
	rescue StandardError => e
		puts e.message.to_s.red
		log.error("#{e.message} PROXY: #{pxhost}:#{pxport} HOST: #{host}")
	end	
	#if i >= 25
	#	break
	#end
	i += 1
end

# dump urls

# dump hashes
