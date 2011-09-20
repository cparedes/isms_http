require 'rubygems'
require 'httparty'

# Custom parser:

class CustomISMSParser < HTTParty::Parser
  @@error_codes = {
    601 => "Authentication Failed",
    602 => "Parse Error",
    603 => "Invalid Category",
    604 => "SMS message size is greater than 160 chars",
    605 => "Recipient Overflow",
    606 => "Invalid Recipient",
    607 => "No Recipient",
    608 => "MultiModem iSMS is busy, can’t accept this request",
    609 => "Timeout waiting for a TCP API request",
    610 => "Unknown Action Trigger",
    611 => "Error in broadcast trigger",
    612 => "System Error – Memory Allocation Failure",
    613 => "Invalid Modem Index",
    614 => "Invalid device model number",
    615 => "Invalid Encoding type",
    616 => "Invalid Time/Date Input",
    617 => "Invalid Count Input",
    618 => "Service Not Available",
    619 => "Invalid Addressee",
    620 => "Invalid Priority value",
    621 => "Invalid SMS text"
    }

  @@status_codes = {
    0 => "Done",
    1 => "Done with error - one or more recipients were not able to receive the message",
    2 => "In progress",
    3 => "Request received",
    4 => "Error",
    5 => "Message ID not found",
    6 => "Distributed to slave",
    7 => "Distribution resulted in error",
    8 => "Distributed among many slaves",
    9 => "API request cancelled"
  }

  def plain
    if body =~ /ID/
      query_parse(body)
    elsif body =~ /Err/
      err_num = error_parse(body)
      err_msg = @@error_codes[err_num]
      { "error" => err_num, "message" => err_msg }
    else
      raise "Not supposed to see this!"
    end
  end

  private

  def query_parse(msg)
    # Messages look roughly like this:
    # "ID: 9 Status: 5"
    # or like this:
    # "ID: 9 Err: 604"
    # Return hash:
    # { "id" => 9, "status" => 5 }
    # if there was an error, 
    # { "id" => 9, "error" => 604 }
    id = msg.match(/ID: ([0-9]+)/)[1]
    if msg =~ /Err/
      err_num = error_parse(msg).to_i
      err_msg = @@error_codes[err_num]

      { "id"      => id,
        "error"   => err_num,
        "message" => err_msg }
    elsif msg =~ /Status/
      status_num = status_parse(msg).to_i
      status_msg = @@status_codes[status_num]

      { "id"      => id,
        "status"  => status_num,
        "message" => status_msg }
    elsif msg =~ /ID/ # Which likely means *only* the ID was given
      { "id" => id }
    else
      raise "Not supposed to see this!"
    end
  end

  def error_parse(msg)
    # Return the error number from this kind of message:
    # "Err: 612"
    msg.chomp!
    err_num = msg.match(/Err: ([0-9]+)/)[1]
    err_num
  end

  def status_parse(msg)
    # Return the status number from this kind of message:
    # "Status: 5"
    status_num = msg.match(/Status: ([0-9])/)[1]
    status_num
  end
end

class ISMS
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
      message_stack << self.class.get("/sendmsg?user=#{@auth[:username]}&passwd=#{@auth[:password]}&cat=#{category}&to=#{recipient}&text=#{msgpart}")
    end
    message_stack
  end

  def query_message_status(id)
    response = self.class.get("/querymsg?user=#{@auth[:username]}&passwd=#{@auth[:password]}&apimsgid=#{id}")
  end
end
