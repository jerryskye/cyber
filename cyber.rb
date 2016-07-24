require 'pry'
require 'yaml'
require 'twitter'
require 'nokogiri'
require 'open-uri'
require 'rufus-scheduler'
require 'data_mapper'

def get_cyber url
	doc = Nokogiri::HTML(open(url))
	max = 0
	doc.at('body').traverse do |node|
		cyber = node.text.scan(/cyber/i).count
		if node.name != 'body' and cyber > max
			max = cyber
		end
	end
	return max
end

client = YAML.load_file('client.yml')

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.db")
class Tweet
	include DataMapper::Resource
	property :id, Serial
	property :tweet, Object
	property :cyber_count, Integer
end

class Message
	include DataMapper::Resource
	property :id, Serial
	property :message, Object
	property :cyber_count, Integer
end
DataMapper.finalize

if ARGV.first == 'pry'
	pry
	Kernel.exit
end

scheduler = Rufus::Scheduler.new

scheduler.every '90s', :overlap => false do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	tweets = Tweet.last.nil?? client.mentions_timeline : client.mentions_timeline({:since_id => Message.last.message.id})
	puts "\tFound #{messages.count} new tweets."
	response = ""
	tweets.each do |tweet|
		valid = true
		unless messages.uris.empty?
			uri = tweet.uris.first.expanded_url.to_s
			unless uri =~ URI::regexp
				response = "URI invalid: #{uri}"
				puts response
				valid = false
				cyber = -1
			end
		else
			response = "\tFound no URIs"
			puts response
			valid = false
			cyber = -2
		end
		if valid
			cyber = get_cyber uri
			response = "Cyber count: #{cyber}"
		end
		client.update("@#{tweet.user.screen_name} " + response, {:in_reply_to_status => tweet})
		Tweet.create(:tweet => tweet, :cyber_count => cyber)
	end
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.every '90s', :first_in => '45s', :overlap => false do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	messages = Message.last.nil?? client.direct_messages_received : client.direct_messages_received({:since_id => Message.last.message.id})
	puts "\tFound #{messages.count} new direct messages."
	response = ""
	messages.each do |message|
		valid = true
		unless messages.uris.empty?
			uri = message.uris.first.expanded_url.to_s
			unless uri =~ URI::regexp
				response = "URI invalid: #{uri}"
				puts response
				valid = false
				cyber = -1
			end
		else
			response = "\tFound no URIs"
			puts response
			valid = false
			cyber = -1
		end
		if valid
			cyber = get_cyber uri
			response = "Cyber count: #{cyber}"
		end
		client.create_direct_message(message.sender, response)
		Message.create(:message => message, :cyber_count => cyber)
	end
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.join
