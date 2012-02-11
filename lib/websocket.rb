require 'eventmachine'
require 'json'
require 'em-websocket'
require 'ostruct'

include ActionView::Helpers::NumberHelper
include ApplicationHelper
include Rails.application.routes.url_helpers


HOST = "0.0.0.0"
PORT = "8080"
SERVER = "127.0.0.1:9999"

EM.run do
  CHANNEL = EM::Channel.new

  EM.connect(*SERVER.split(":")) do |connection|
    connection.send_data(["monitor", ''].to_json)
    def connection.receive_data(data)
      (@buf ||= BufferedTokenizer.new("\x00")).extract(data).each do |packet|
        cmd, result = JSON.load(packet)
        next  unless cmd == "monitor"
        begin
        if result[0] == "block"
          p result
          block = STORE.get_block(result[1]["hash"])
          ctx = OpenStruct.new(:blk => block)
          template = File.read(File.join(Rails.root, "app/views/blocks/_blk.html.haml"))
          res = Haml::Engine.new(template).render(ctx)
          CHANNEL.push "<tr>#{res.gsub!("\n", '')}</tr>"
        end
          rescue
          p $!
          puts *$@
          end
      end
    end
  end

  p 'running'

  EventMachine::WebSocket.start(:host => HOST, :port => PORT) do |ws|
    puts "client connected"

    ws.onopen do
      sid = CHANNEL.subscribe {|msg| ws.send msg.to_json }
    end

    ws.onclose { puts "Connection closed" }

  end

  puts "websocket listening on #{HOST}:#{PORT}"
end
