#!/usr/bin/env ruby

require 'colorize'
require 'net/smtp'
require 'getoptlong'
require 'pathname'

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--to', '-t', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--from', '-f', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--path', '-p', GetoptLong::REQUIRED_ARGUMENT ]
)

def help
	puts <<-EOF
spam.rb -t|--to <email addr> -f|--from <email addr> -p|--path <path> [-h|--help]

-t|--to		Email address to send the spam to.
-f|--from	Email address to sent the spam from.
-p|--path	Directory to look for files to send.
-h|--help	Displays this useful message.
	EOF
	exit 0
end
	
def send_mail_w_file(_to, _from, _subject, _file)
	filecontent = File.read(_file)
	encodedcontent = [filecontent].pack("m")

	marker = '===AUNIQUEMARKER==='

	body =<<EOF
Please find the requested document attached.
EOF

	# Define the main headers
	part1 =<<EOF
From: A Trusted Sender <#{_from}>
To: Important User <#{_to}>
Subject: #{_subject}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}
--#{marker}
EOF

	# Define the message section
	part2 =<<EOF
Content-Type: text/plain
Content-Transfer-Encoding:8bit

#{body}
--#{marker}
EOF

	# Define the attachment section
	part3 =<<EOF
Content-Type: multipart/mixed; name=\"#{_file}\"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{_file}"

#{encodedcontent}
--#{marker}--
EOF

	mailtext = part1 + part2 + part3

	begin
		Net::SMTP.start('localhost') do |smtp|
			smtp.sendmail(mailtext, _from, [_to])
		end
	rescue Exception => e
		puts "Exception occurred: #{e}".red
	end
end

def get_files(_path)
	_files = Array.new
	pn = Pathname.new(_path)
	#puts "#{pn.inspect}".yellow
	pn.each_entry { |entry|
		next if entry.basename.to_s =~ /^\.\.?$/
		next if File.directory?("#{_path}/#{entry.basename}")
		#puts "#{entry.basename}".magenta
		_files.push("#{_path}/#{entry.basename}")
	}
	return _files
end

opts.each do |opt, arg|
	case opt
		when '--help'
			help
		when '--to'
			@to = arg.to_s
		when '--from'
			@from = arg.to_s
		when '--path'
			@path = arg.to_s
		else
			puts "No options specified, or option not understood.".red
			help
	end
end

if ! defined?(@to) || @to == ""
	puts "A target email address must be specified.".red
	help
end

if ! defined?(@from) || @from == ""
	puts "A source email address must be specified.".red
	help
end

if ! defined?(@path) || @path == ""
	puts "A path containing files to be sent must be speficied.".red
	help
end

print "Collecting files....".green
files = get_files(@path)
puts "done.".green

#puts files.inspect.to_s.cyan

i = 0
begin
	print "Sending spam...".green
	files.each do |f|
		send_mail_w_file(@to, @from, 'SEu TVM Important Documents', f)
		if i >= 10 
			break
		end
		i += 1
	end
	puts "done.".green
rescue Exception => e
	puts "Error: #{e}".red
end
