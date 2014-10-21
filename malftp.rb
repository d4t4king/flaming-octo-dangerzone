#!/usr/bin/env ruby

require 'colorize'
require 'net/ftp'
require 'getoptlong'
require 'pathname'

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--path', '-p', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--up', '-u', GetoptLong::NO_ARGUMENT ],
	[ '--down', '-d', GetoptLong::NO_ARGUMENT ]
)

def help
	puts <<-EOF
malftp.rb -p|--path <path> [-u|--up]* [-d|--down] [-h|--help] 

-p|--path	Required. The path to look for files to upload*.
-u|--up		Specifies the intent to upload files.
-d|--down	Specifies the intent to download files.
-h|--help	Displays this message and exits.
	EOF
	exit 0
end

opts.each do |opt, arg|
	case opt
		when '--help'
			help
		when '--path'
			@path = arg.to_s
		when '--up'
			@upload = true
			@download = false
		when '--down'
			@download = true
			@upload = false
		else
			puts "No option specified, or option not understood.".red
			help
	end
end

if ! @upload && ! @download
	puts "Upload or download not specified.".red
	help
end 

@files_to_upload = Array.new
@files_to_download = Array.new

def get_login
	if File.exist?("ftp.login")
		@user, @pass = File.new("ftp.login").read.chomp.split(',')
	end
end

def get_up_files(_path)
	pn = Pathname.new(_path)
	pn.each_entry { |entry|
		@files_to_upload.push("#{_path}/#{entry.basename}")
	}
end

def get_down_files
	ftp = Net::FTP.new('salt.dataking.us')
	ftp.login(user=@user, passwd=@pass)
	list = ftp.list
	list.each { |item|
		next if item =~ /^drwx/					# skip directories
		next if item =~ /^[0-9][0-9][0-9]/		# skip return codes
		fields = item.split(/ /)
		#puts "### DEBUG: #{fields.last}".yellow
		@files_to_download.push(fields.last)
	}
	ftp.close
end

get_login

if @upload
	get_up_files(@path)

	ftp = Net::FTP.new('salt.dataking.us')
	ftp.login(user=@user, passwd=@pass)
	puts "Uploading files...".blue
	@files_to_upload.each { |file|
		dir, base = File.split(file)
		next if base =~ /^\.\.?/
		ftp.putbinaryfile("#{dir}/#{base}", base)
		print "#".blue
	}
	puts
end

if @download
	if @path
		if Dir.exist?(@path)
			Dir.chdir(@path)
		else
			raise "Specified directory doesn't exist."
		end
	else
		if Dir.exist?("ftp_down")
			Dir.chdir("ftp_down")
		else
			Dir.mkdir("ftp_down")
			Dir.chdir("ftp_down")
		end
	end

	get_down_files

	ftp = Net::FTP.new('salt.dataking.us')
	ftp.login(user=@user, passwd=@pass)
	puts "Downloading files...".green
	@files_to_download.each { |file|
		next if file =~ /^\.\.?/
		next if File.directory?(file)
		begin
			ftp.getbinaryfile(file)
			print "#".green
		rescue Exception => e
			puts
			puts "Error on file: #{file}".red
			puts "#{e.inspect}".red
		end
	}
	puts
end
