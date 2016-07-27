require 'pry'
require 'yaml'
require 'twitter'
require 'nokogiri'
require 'httparty'
require 'uri'
require 'rufus-scheduler'
require 'data_mapper'

def get_cyber url
	max = 0
    url = "http://#{url}" unless url.to_s =~/^https?:\/\//
	begin
	doc = Nokogiri::HTML(HTTParty.get(url))
	doc.at('body').traverse do |node|
		text = node.text
		text = text.encode("UTF-8", :invalid=>:replace, :replace=>"?") unless text.valid_encoding?
		cyber = text.scan(/cyber/i).count
		if node.name != 'body' and cyber > max
			max = cyber
		end
	end
	rescue => e
		str = "#{e.class}:#{e}\n#{e.backtrace.join("\n")}"
		puts str
		puts
		client.create_direct_message("jerrysky3", str)
		return "Something went wrong. Sorry about that."
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

unless ARGV.empty?
	pry
	Kernel.exit
end

scheduler = Rufus::Scheduler.new

scheduler.every '70s', :first_in => '1s' do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	tweets = Tweet.last.nil?? client.mentions_timeline : client.mentions_timeline({:since_id => Tweet.last.tweet.id})
	puts "\tFound #{tweets.count} new tweets."
	response = ""
	tweets.reverse_each do |tweet|
		valid = true
		unless tweet.uris.empty?
			uri = tweet.uris.first.expanded_url
			unless uri.to_s =~ URI::regexp
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
			if cyber.is_a? Fixnum
				response = "Cyber count: #{cyber}\n#{uri}"
			else
				response = cyber
				cyber = -3
			end
		end
		begin
		Tweet.create(:tweet => tweet, :cyber_count => cyber)
		client.update("@#{tweet.user.screen_name} " + response, {:in_reply_to_status => tweet})
		rescue => e
			str = "Tweet id: #{tweet.id}: #{e.class}: #{e}\n#{e.backtrace.join("\n")}"
			puts str
			puts
			client.create_direct_message("jerrysky3", str)
		end
	end
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.every '70s', :first_in => '35s' do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	messages = Message.last.nil?? client.direct_messages : client.direct_messages({:since_id => Message.last.message.id})
	puts "\tFound #{messages.count} new direct messages."
	response = ""
	messages.reverse_each do |message|
		valid = true
		unless message.uris.empty?
			uri = message.uris.first.expanded_url
			unless uri.to_s =~ URI::regexp
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
			if cyber.is_a? Fixnum
				response = "Cyber count: #{cyber}\n#{uri}"
			else
				response = cyber
				cyber = -3
			end
		end
		begin
		Message.create(:message => message, :cyber_count => cyber)
		client.create_direct_message(message.sender, response)
		rescue => e
			str = "Message id: #{message.id}: #{e.class}:#{e}\n#{e.backtrace.join("\n")}"
			puts str
			puts
			client.create_direct_message("jerrysky3", str)
		end
	end
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.join
