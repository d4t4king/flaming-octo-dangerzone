#!/usr/bin/env ruby

require 'colorize'
require 'rest_client'
require 'getoptlong'
require 'json'
require 'uri'
require 'readline'
require 'pathname'
require 'csv'
require 'filesize'
require 'logger'

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--path', '-p', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--csv', GetoptLong::NO_ARGUMENT ],
	[ '--skip', '-s', GetoptLong::NO_ARGUMENT ]
)

def help
	puts <<-EOF
vtupload.rb -p|--path <path> [-f|--file <FILE>] [-h|--help] [--csv] [-s|--skip]

-p|--path		Required.  The relative or absolute path where the files to upload are stored.
-f|--file		Single file to upload and report.
--csv			Write report data to vtupload.csv
--skip			Skip uploading files, and just search using the MD5 checksum.
-|--help		Display this message and exit.
	EOF
	exit 0
end 

opts.each do |opt, arg|
	case opt
		when '--help'
			help
		when '--file'
			@file = arg.to_s
		when '--path'
			@path = arg.to_s
		when '--csv'
			@csv = true
		when '--skip'
			@skip = true
		else
			help
	end
end

if ! @path
	help
end

# set up the log file
logfile = File.open("vtupload.log", File::WRONLY | File::APPEND | File::CREAT)
@logger = Logger.new(logfile)
@logger.level = Logger::INFO

if File.exists?("api.key")
	@apikey = File.read("api.key").chomp!
	@logger.info("Got API key.")
else 
	raise "Couldn't find api.key file to get apikey!"
	@logger.fatal("Couldn't find api.key file to get apikey!")
end
@files_to_check = Array.new
checked_files_to_report = Array.new

def send_file(fqfile)
	puts "Fully qualified file name: #{fqfile}"
	@logger.info("Sending file: #{fqfile}")
	__file = Pathname.new(fqfile).basename

	fs = File.size?(fqfile)
	puts "** #{Filesize.from("#{fs} B").pretty} **".magenta
	if fs.nil? || fs == 0
		return nil
	elsif fs > 15728540
		puts "File size too big: #{Filesize.from("#{fs} B").pretty}".red
		@logger.error("File size too big: #{Filesize.from("#{fs} B").pretty}")
		return nil
	end

	response = JSON.parse(RestClient.post('https://www.virustotal.com/vtapi/v2/file/scan',
		:apikey => @apikey, :file => "#{__file}", :file => File.new(fqfile)))

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
		params = {:resource => __file, :apikey => @apikey}
		#rep_response = RestClient.post(url, params)
		begin
			rep_response = JSON.parse(RestClient.post(url, params))
			#puts "|#{rep_response.inspect}|"
			if rep_response["verbose_msg"] == "The requested resource is not among the finished, queued or pending scans"
				puts "Hash not found.".yellow
				puts "Resource is either being scanned, or is unknown.".yellow
				return nil
			#elsif RestClient.post(url, params).nil? ||
			#	  RestClient.post(url, params) == ""
			#	puts "Got no response for resource: #{__file}"
			#	return nil
			end
		rescue JSON::ParserError => e
			puts "#{e.message}".magenta
			puts RestClient.post(url, params).inspect
			return nil
		end
		print "md5: "
		puts "#{rep_response["md5"]}".green
		print "sha1: "
		puts "#{rep_response["sha1"]}".green
		puts "permalink: #{rep_response['permalink']}"
		print "Found ".light_black
		print "#{rep_response["positives"]}".yellow
		print " out of ".light_black
		puts "#{rep_response["total"]}".green
		if rep_response['scans'].count == 0
			puts "No scans to report".yellow
		else 
			rep_response['scans'].sort.each { |scan|
				if scan[1]["detected"] == true
					print "#{scan[0]}: ".green
					puts  "#{scan[1]["result"]}".red
				end
			}
		end
		@logger.info("File: #{__file}.  Found #{rep_response["positives"]} out of #{rep_response["total"]}.")
	rescue StandardError => e
		#$stderr.print "Report request files: " + $!
		$stderr.print "Exception: #{e.inspect}\n".red
		@logger.error("ERROR: #{e.message}")
	end
end 

def get_csv_report(_file)
	begin
		url = "https://www.virustotal.com/vtapi/v2/file/report"
        params = {:resource => _file, :apikey => @apikey}
        #rep_response = RestClient.post(url, params)
		begin
        	rep_response = JSON.parse(RestClient.post(url, params))
        	#puts "|#{rep_response.inspect}|"
			if rep_response["verbose_msg"] == "The requested resource is not among the finished, queued or pending scans"
				puts "Hash not found.".yellow
				puts "Resource is either being scanned, or is unknown.".yellow
				sleep(20)
				return nil
			#elsif RestClient.post(url, params).nil? ||
			#	  RestClient.post(url, params) == ""
			#	puts "Got no response for resource: #{__file}"
			#	return nil
			end
		rescue JSON::ParserError => pe
			puts "#{pe.message}".magenta
			#puts RestClient.post(url, params).inspect
			sleep(20)
			return nil
		end
		detects = Array.new
		print "File: "
		puts "#{_file}".green
		print "MD5: "
		puts "#{rep_response['md5']}".green
		print "Found ".light_black
		if rep_response['positives'] == 0
			print "#{rep_response['positives']}".green
		else
			print "#{rep_response['positives']}".yellow
		end
		print " out of ".light_black
		puts "#{rep_response['total']}".red
		rep_response['scans'].sort.each { |scan|
			if scan[1]['detected'] == true
				if ! detects.include?("#{scan[0]}:#{scan[1]["result"]}")
					detects.push("#{scan[0]}:#{scan[1]["result"]}")
				end
			end
		}
		@logger.info("File: #{_file}. Found #{rep_response["positives"]} out of #{rep_response["total"]}.")
		csv_data = ["#{_file}", "#{rep_response['md5']}", "#{rep_response['sha1']}",
			"#{rep_response['positives']}", "#{rep_response['total']}", "#{detects.join("|")}"]
		return csv_data
	rescue StandardError => e
		$stderr.print "Exception #{e.inspect}\n".red
		@logger.error("ERROR: #{e.message}")
		return nil
	end
end

def populate_files(xpath)
	@logger.info("Collecting files in #{@path}.")
	if xpath.nil?
		raise "Null argument.  Script called without arguments?"
	end
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
					puts "Process file: #{xpath}/#{dir}".green
					if ! @files_to_check.include?("#{xpath}/#{dir}")
						@files_to_check.push("#{xpath}/#{dir}")
					end
				end
			end
		end
	end
	@logger.info("File collection done.")
end

### Start Main
if @file								# just process one file
	if @skip
		puts "Skipping file uploads.  Let see what we get just pulling reports with hashes."
		@logger.info("Skipping file uploads.  Let see what we get just pulling reports with hashes.")
	else
		puts "send_file".green
		@logger.info("Sending file: #{@path}/#{@file}")
		send_file("#{@path}/#{@file}")
		puts "Wait 300 secs..."
		#Readline.readline('> ', true)
		sleep(300)
	end
	puts "get_report()".green
	get_report(@file)					# filename as md5 checksum
else									# process all files in the directory tree 
	populate_files(@path)

	if @skip
		puts "Skipping file uploads.  Let see what we get just pulling reports with hashes."
		@logger.info("Skipping file uploads.  Let see what we get just pulling reports with hashes.")
	else
		#counter = 0;
		@files_to_check.each { |file|
			send_file(file)			# file is full (relative) path here
			sleep(20)
			checked_files_to_report.push(file)
			#counter += 1
			#break if counter >= 10
		}
	end

	#puts "Last submission.  Check permalink and hit ENTER, when done.".light_black
	#Readline.readline('> ', true)

	if @csv
		@logger.info("Saving to csv.")
		lc = 0
		if @skip
			CSV.open("vtupload.csv", "wb") do |csv|
				@files_to_check.each { |file|
					basename = Pathname.new(file).basename
					if lc == 0
						csv << ["Filename", "MD5 Checksum", "SHA1 Checksum",
							"Found", "Total", "Detections"]
					else
						line = get_csv_report(basename)
						next if line.nil?
						csv << line
					end
					sleep(20)
					lc += 1
				}
			end
		else
			CSV.open("vtupload.csv", "wb") do |csv|
				checked_files_to_report.each { |file|
					basename = Pathname.new(file).basename
					if lc == 0
						csv << ["Filename", "MD5 Checksum", "SHA1 Checksum",
							"Found", "Total", "Detections"]
					else
						line = get_csv_report(basename)
						next if line.nil?
						csv << line
					end
					sleep(20)
					lc += 1
				}
			end
		end
	else
		if @skip
			@files_to_check.each { |file|
				basename = Pathname.new(file).basename
				get_report(basename)
				sleep(20)
			}
		else
			checked_files_to_report.each { |file|
				basename = Pathname.new(file).basename
				get_report(basename)
				sleep(20)
			}
		end
	end
end
@logger.info("All tasks complete. Exiting.")
exit 0
