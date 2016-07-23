require 'yaml'
require 'twitter'
require 'nokogiri'
require 'open-uri'
require 'rufus-scheduler'
require 'data_mapper'

def get_cyber url
	doc = Nokogiri::HTML(open(url))
	"Cyber count: #{doc.at('head > title').text.scan('cyber').count + doc.at('body').text.scan('cyber').count}"
end

client = YAML.load_file('client.yml')

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.db")
class Tweet
	include DataMapper::Resource
	property :id, Serial
	property :tweet, Object
	property :cyber_count, Integer
end
DataMapper.finalize

scheduler = Rufus::Scheduler.new
scheduler.every '1m', :first_in => '1s', :overlap => false do
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job started.")
	tweets = Tweet.last.nil?? client.mentions_timeline : client.mentions_timeline({:since_id => Tweet.last.tweet.id})
	puts "\tFound #{tweets.count} tweets."
	tweets.each do |tweet|
		if tweet.uris.empty?
			puts "\tNo URIs"
		end
		uri = tweet.uris.first.expanded_url.to_s
		unless uri =~ URI::regexp
			puts "\t\e[1mURI invalid: \e[0m#{uri}"
			next
		end
		cyber = get_cyber(uri)
		client.update("@#{tweet.user.screen_name} " + cyber, {:in_reply_to_status => tweet})
		Tweet.create(:tweet => tweet, :cyber_count => cyber[/\d+/])
	end
	puts Time.now.strftime("%d/%m/%Y %H:%M:%S: Job ended.")
end

scheduler.join
