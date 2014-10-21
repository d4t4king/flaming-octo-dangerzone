#!/usr/bin/env ruby

require 'colorize'
require 'net/ping'
#require 'whois'

def gen_random_ip
	first = (0..255).to_a.sample
	second = (0..255).to_a.sample
	third = (0..255).to_a.sample
	fourth = (0..255).to_a.sample

	#puts "### DEBUG: #{first}.#{second}.#{third}.#{fourth}".green
	randip = "#{first}.#{second}.#{third}.#{fourth}".green
	return randip
end

#c = Whois::Client.new

# ICMP (?)
(0..99999).each { |itr|
	randip = gen_random_ip
	pe = Net::Ping::External.new(randip)
	#r = c.lookup(randip)
	#puts "#{r}".magenta
	if pe.ping?
		puts "#{randip}".green
	else 
		puts "#{randip}".red
	end
}

# TCP
(0..99999).each { |itr|
	randip = gen_random_ip
	pe = Net::Ping::TCP.new(randip, 6667)
	if pe.ping?
		puts "#{randip}".cyan
	else 
		puts "#{randip}".yellow
	end
}
