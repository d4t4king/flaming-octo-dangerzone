#!/usr/bin/env ruby

require 'colorize'
require 'net/ftp'
require 'getoptlong'
require 'pathname'

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--path', '-p', GetoptLong::REQUIRED_ARGUMENT ]
)

def help
	puts <<-EOF
malftp.rb -p|--path <path> [-h|--help] 
	EOF
	exit 0
end

opts.each do |opt, arg|
	case opt
		when '--help'
			help
		when '--path'
			@path = arg.to_s
		else
			puts "No option specified, or option not understood.".red
			help
	end
end

def get_files(_path)
	pn = Pathname.new(_path)
	pn.each_filename do { |file|
		puts file
	}
end

get_files(@path)

#ftp = Net::FTP.new('salt.dataking.us')
#ftp.login(user="joe", passwd="pep")

