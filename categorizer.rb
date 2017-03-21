#!ruby

require 'filemagic'

smallstr = "\\small"
mediumstr = "\\medium"
largestr = "\\large"
xlargestr = "\\xlarge"
smallfile = 50001
mediumfile = 1000001
largefile = 6000001
root_dir = "pulls"
all_files = root_dir

filemagic = FileMagic.new
Dir.foreach(all_files) do |item|
	if !File.directory?(item)
		outstring = fm.File(item)
		puts outstring
	end
end