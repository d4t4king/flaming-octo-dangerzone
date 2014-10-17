#!/usr/bin/env ruby

require 'colorize'
require 'net/ftp'
require 'getoptlong'

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

ftp = Net::FTP.new('salt.dataking.us')

