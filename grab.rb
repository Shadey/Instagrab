#!/usr/bin/env ruby
require "json"
require "open-uri"
require "nokogiri"
require "net/http"
require "uri"
class Node
	attr_accessor :code,:video,:src
	def initialize(node_json)
		@code = node_json["code"]
		@video = node_json["is_video"]
		@src = node_json["display_src"]
	end
	def get_video
		page = fetch_page("https://instagram.com/p/#{@code}")
		return page["entry_data"]["PostPage"][0]["media"]["video_url"]
	end
end

class IGPage
	def initialize(json)
		@username = json["entry_data"]["ProfilePage"][0]["user"]["username"]
		@nodes = json["entry_data"]["ProfilePage"][0]["user"]["media"]["nodes"]
		@next_page = json["entry_data"]["ProfilePage"][0]["user"]["media"]["page_info"]["has_next_page"]
		@end = json["entry_data"]["ProfilePage"][0]["user"]["media"]["page_info"]["end_cursor"]
		@token = json["config"]["csrf_token"]
		@user_id = json["entry_data"]["ProfilePage"][0]["user"]["id"]
		Dir.mkdir @username unless File.exists? @username
	end
	def downloadPosts
		@nodes.each do |node|
			node = Node.new(node)
			if !node.video
				f = File.new("#{@username}/#{node.code}.jpg","w+")
				puts "Downloading #{node.src}"
				f << open(node.src).read
			else
				f =  File.new("#{@username}/#{node.code}.mp4","w+")
				puts "#Downloaing #{node.get_video}"
				f << open(node.get_video).read
			end
			f.close
			sleep 1
		end
		if @next_page
			get_next_page
		end
	end
	def get_next_page
		uri = URI.parse("https://www.instagram.com/query/")
		request = Net::HTTP::Post.new(uri)
		request.content_type = "application/x-www-form-urlencoded"
		request["User-Agent"] = "Mozilla/5.0 (X11; Linux i686; rv:47.0) Gecko/20100101 Firefox/47.0"
		request["Accept"] = "*/*"
		request["Accept-Language"] = "en-US,en;q=0.5"
		request["X-Csrftoken"] = @token
		request["X-Instagram-Ajax"] = "1"
		request["X-Requested-With"] = "XMLHttpRequest"
		request["Referer"] = "https://www.instagram.com/" 
		request["Cookie"] = "csrftoken=#{@token};"
		request["Connection"] = "keep-alive"
		request.set_form_data(
		  "q" => "ig_user(#{@user_id}) { media.after(#{@end}, 12) {
		  count,
		  nodes {
		    caption,
		    code,
		    comments {
		      count
		    },
		    comments_disabled,
		    date,
		    dimensions {
		      height,
		      width
		    },
		    display_src,
		    id,
		    is_video,
		    likes {
		      count
		    },
		    owner {
		      id
		    },
		    thumbnail_src,
		    video_views
		  },
		  page_info
		}
		 }",
		  "ref" => "users::show",
		)

		response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
		  http.request(request)
		end
		json = JSON.parse response.body
		if json["status"] == "ok"
			@nodes = json["media"]["nodes"]
			@end = json["media"]["page_info"]["end_cursor"]
			@next_page = json["media"]["page_info"]["has_next_page"]
			downloadPosts
		end
	end
end

def fetch_page(url)
	page = Nokogiri::HTML(open(url))
	body = page.search("script").select do |s|
		s.text =~ /window\._sharedData/
	end
	json = JSON.parse body.first.text.split(" = ").last[0...-1]
	return json
end
downloader = IGPage.new fetch_page(ARGV[0])
downloader.downloadPosts
