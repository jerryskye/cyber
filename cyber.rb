#!/usr/bin/env ruby

require 'yaml'
require 'twitter'
require 'mechanize'

@client = YAML.load_file('client.yml')
@mechanize = Mechanize.new
unless File.exist? 'persistent/timestamps.yml'
	File.write('persistent/timestamps.yml', YAML.dump(
		{
			:last_mention_id => @client.mentions_timeline.first.id,
			:last_message_id => @client.direct_messages.first.id
		}))
end
@timestamps = YAML.load_file('persistent/timestamps.yml')

def get_cyber uri
	begin
	max = 0
	@mechanize.get(uri).at('body').traverse do |node|
		text = node.text
		text = text.encode("UTF-8", :invalid=>:replace, :replace=>"?") unless text.valid_encoding?
		cyber = text.scan(/cyber/i).count
		if node.name != 'body' and cyber > max
			max = cyber
		end
	end
	rescue => e
		str = "#{e.class}:#{e}\n#{e.backtrace.join("\n")}"
		@client.create_direct_message("jerrysky3", str)
		return "Something went wrong. Sorry about that."
	end
	return "Cyber count: #{max}\n#{uri}"
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

def handle item
	begin
	unless item.uris.empty?
		uri = item.uris.first.expanded_url
		if uri.to_s =~ URI::regexp
			reply_to(item, get_cyber(uri))
		else
			reply_to(item, "URI invalid: #{uri}")
		end
	end
	rescue => e
		str = "#{e.class}:#{e}\n#{e.backtrace.join("\n")}"
		@client.create_direct_message("jerrysky3", str)
	end
end

mentions = @client.mentions_timeline({:since_id => @timestamps[:last_mention_id]})
messages = @client.direct_messages({:since_id => @timestamps[:last_message_id]})
mentions.reverse_each {|mention| handle mention }
messages.reverse_each {|message| handle message }
@timestamps[:last_mention_id] = mentions.first.id unless mentions.empty?
@timestamps[:last_message_id] = messages.first.id unless messages.empty?
File.write('persistent/timestamps.yml', YAML.dump(@timestamps))
