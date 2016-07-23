require 'pry'
require 'yaml'
require 'twitter'
require 'nokogiri'
require 'open-uri'

def get_cyber url
	doc = Nokogiri::HTML(open(url))
	"The string 'cyber' occurs #{doc.at('head > title').text.scan('cyber').count + doc.at('body').text.scan('cyber').count} times in you URL."
end

client = YAML.load_file('client.yml')

pry

#tweet = client.mentions_timeline.first
#client.update("@#{tweet.user.screen_name} " + get_cyber(tweet.uris.first.expanded_url.to_s), {:in_reply_to_status => tweet})
