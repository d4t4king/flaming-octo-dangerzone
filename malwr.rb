#!/usr/bin/env ruby

require 'colorize'
require 'rest_client'
require 'getoptlong'
require 'json'
require 'uri'
require 'readline'
require 'pathname'

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--path', '-p', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--file', '-f', GetoptLong::OPTIONAL_ARGUMENT ]
)

opts.each do |opt, arg|
	case opt
		when '--help'
			puts <<-EOF
malwr.rb [-f <FILE>] -p <path>
			EOF
		when '--file'
			@file = arg.to_s
		when '--path'
			@path = arg.to_s
	end
end


@apikey = "***REMOVED***"
@files_to_check = Array.new
@checked_files_to_report = Array.new

def send_file(fqfile)
	puts "Fully qualified file name: #{fqfile}"
	basename = Pathname.new(fqfile).basename
	puts "Basename:  #{basename}"

	response = JSON.parse(RestClient.post('https://www.virustotal.com/vtapi/v2/file/scan',
		:apikey => @apikey, :file => "#{basename}", :file => File.new(fqfile)))

	print "scan_id: "
	puts "#{response['scan_id']}".green
	print "response_code: "
	if response['response_code'] = 1
		puts "#{response['response_code']}".green
	else 
		puts "#{response['response_code']}".red
	end
	print "md5: "
	puts "#{response['md5']}".green
	print "sha1: "
	puts "#{response['sha1']}".green
	puts "permalink: #{response['permalink']}"
	puts "verbose_msg: #{response['verbose_msg']}"
end

def get_report(__file)
	begin
		url = "https://www.virustotal.com/vtapi/v2/file/report"
		params = {:resource => __file.to_s, :apikey => @apikey}
		rep_response = JSON.parse(RestClient.post(url, params))
		print "md5: "
		puts "#{rep_response["md5"]}".green
		print "sha1: "
		puts "#{rep_response["sha1"]}".green
		puts "permalink: #{rep_response['permalink']}"
		print "Found ".light_black
		print "#{rep_response["positives"]}".yellow
		print " out of ".light_black
		puts "#{rep_response["total"]}".green
		rep_response['scans'].sort.each { |scan|
			if scan[1]["detected"] == true
				print "#{scan[0]}: ".green
				puts  "#{scan[1]["result"]}".red
			end
		}
	rescue Exception => e
		#$stderr.print "Report request files: " + $!
		$stderr.print "Exception: #{e.inspect}\n".red
	end
end 

def populate_files(xpath)
	Dir.new(xpath).entries.each do |dir|
		next if dir =~ /^\.\.?$/
		#puts "### DEBUG: #{dir}".red
		if File.directory?("#{@path}/#{dir}")
			_path = "#{xpath}/#{dir}"
			Dir.new(_path).entries.each do |sdir|
				next if sdir =~ /^\.\.?$/
				#puts "### DEBUG: #{_path}".red
				if File.directory?(sdir)
					# shouldn't be any more directories, but needs handling
					raise "Found directory where none expected. ### #{sdir}"
				else 
					puts "Process file: #{_path}/#{sdir}".green
					if ! @files_to_check.include?("#{_path}/#{sdir}")
						@files_to_check.push("#{_path}/#{sdir}")
					end
				end
			end
		else
			#puts "Found file: #{xpath}/#{dir}".red
			Dir.new(xpath).entries.each do |dir|
				next if dir =~ /^\.\.?$/
				#puts "### DEBUG: #{_path}".red
				if File.directory?(dir)
					# shouldn't be any more directories, but needs handling
					raise "Found directory where none expected. ### #{dir}"
				else 
					puts "Process file: #{dir}".green
					if ! @files_to_check.include?("#{dir}")
						@files_to_check.push("#{dir}")
					end
				end
			end
		end
	end
end

if @file									# just process one file
	puts "send_file".green
	send_file("#{@path}/#{@file}")
	puts "Wait 300 secs..."
	#Readline.readline('> ', true)
	sleep(300)
	puts "get_report()".green
	get_report(@file)						# filename as md5 checksum
else										# process all files in the directory tree 
	populate_files(@path)

	counter = 0;
	@files_to_check.each { |file|
		next if file =~ /\/..\//
		send_file(file)						# file is full (relative) path here
		sleep(20)
		@checked_files_to_report.push(file)
		counter += 1
		break if counter >= 10
	}

	sleep(300)

	@checked_files_to_report.each { |file|
		get_report(file)
	}
end
