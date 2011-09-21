require 'rubygems'
require 'httparty'
require 'isms_http/exceptions'
require 'isms_http/parser'

# Main module for ISMS library.
module ISMS
  class HTTP
    attr_reader :url
    include HTTParty
    parser CustomISMSParser
    format :plain

    def initialize(url, user, password)
      @auth = { :username => user, :password => password }
      @url = url
      self.class.base_uri(@url)
    end

    # recipient: Number/alias for the person you want to text
    # msg: Full text message to send
    # max_msgs: Maximum number of messages to send if message is too
    # long.  Defaults to 0 messages (which means, split it up into as many
    # messages as it takes).
    def send_message(recipient, msg, max_msgs=0)
      category = 1 # Corresponds to &cat=1 in API
      offset = 0
      max_msgs = 999 if max_msgs == 0
      message_stack = []
      while max_msgs > 0 and msg.length > offset
        msgpart = URI.escape(msg[offset, 160])
        offset += 160
        split_message = self.class.get("/sendmsg?user=#{@auth[:username]}&passwd=#{@auth[:password]}&cat=#{category}&to=#{recipient}&text=#{msgpart}")
        message_stack << split_message["id"]
      end
      message_stack
    end

    def query_message_status(id)
      response = self.class.get("/querymsg?user=#{@auth[:username]}&passwd=#{@auth[:password]}&apimsgid=#{id}")
    end
  end
end
