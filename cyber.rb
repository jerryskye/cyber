require 'pry'
require 'yaml'
require 'twitter'
require 'mechanize'
require 'rufus-scheduler'
require 'data_mapper'

@client = YAML.load_file('client.yml')
@mechanize = Mechanize.new

def get_cyber url
	begin
	max = 0
	@mechanize.get(url).at('body').traverse do |node|
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
		@client.create_direct_message("jerrysky3", str)
		return "Something went wrong. Sorry about that."
	end
	return max
end

def reply_to item, response
	case item
	when Twitter::Tweet
		@client.update("@%s %s" % [item.user.screen_name, response], {:in_reply_to_status => item})
	when Twitter::DirectMessage
		@client.create_direct_message(item.sender, response)
	else
		raise "Something went horribly wrong."
	end
end

def check_for last_item
	items = case last_item
			 when Tweet
				 @client.mentions_timeline({:since_id => last_item.tweet.id})
			 when Message
				 @client.direct_messages({:since_id => last_item.message.id})
			 else
				 Array.new
			 end
	puts "\tFound #{items.count} new #{last_item.class.to_s.downcase}s."
	response = ""
	items.reverse_each do |item|
		valid = true
		unless item.uris.empty?
			uri = item.uris.first.expanded_url
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
		last_item.class.create(last_item.class.to_s.downcase.to_sym => item, :cyber_count => cyber)
		reply_to(item, response)
		rescue => e
			puts str = "#{last_item.class} id: #{item.id}. #{e.class}: #{e}\n#{e.backtrace.join("\n")}\n"
			@client.create_direct_message("jerrysky3", str.chop)
		end
	end
end

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

class Article
	include DataMapper::Resource
	property :id, Serial
	property :item, Object
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
	check_for Tweet.last
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.every '70s', :first_in => '35s' do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	check_for Message.last
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.join
