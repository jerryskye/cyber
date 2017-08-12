require 'mechanize'
require 'roda'

class App < Roda
	plugin :render, engine: 'haml'
	MECH = Mechanize.new

	def url str
		ENV["BASE_URL"] + str
	end

	def get_count url, keyword
		begin
		max = 0
		MECH.get(url).at('body').traverse do |node|
			text = node.text
			text = text.encode("UTF-8", :invalid=>:replace, :replace=>"?") unless text.valid_encoding?
			cyber = text.scan(/#{keyword}/i).count
			if node.name != 'body' and cyber > max
				max = cyber
			end
		end
		return CGI.escapeHTML("#{max} occurrences of #{keyword} in #{url}")
		rescue => e
			STDERR.puts e.class
			STDERR.puts e
			return "Sorry, something went wrong: #{e}"
		end
	end

	route do |r|
		r.root do
			view :index
		end

		r.post 'count' do
			(not r['url'].nil? and not r['keyword'].nil? and r['url'].size > 0 and r['keyword'].size > 0)? get_count(r['url'], r['keyword']) : 'You have to provide an URL and a keyword.'
		end

		r.get 'robots.txt' do
			"User-agent: *\nDisallow: /\n"
		end
	end
end
