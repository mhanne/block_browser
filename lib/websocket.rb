require 'eventmachine'
require 'json'
require 'em-websocket'
require 'ostruct'

include ActionView::Helpers::NumberHelper
include ApplicationHelper
include Rails.application.routes.url_helpers

def compile_block_haml(block)
  ctx = OpenStruct.new(:blk => block)
  template = File.read(File.join(Rails.root, "app/views/blocks/_blk.html.haml"))
  res = Haml::Engine.new(template).render(ctx)
  "<tr>#{res.gsub!("\n", '')}</tr>"
end

class BitcoinConnection < EM::Connection
  def initialize(host, port, channel)
    @host, @port, @channel = host, port, channel
    @buf = BufferedTokenizer.new("\x00")
    send_data(["monitor", ''].to_json)
    puts "bitcoin server connected"
  end

  def receive_data(data)
    @buf.extract(data).each do |packet|
      cmd, result = JSON.load(packet)
      next  unless cmd == "monitor"
      begin
        puts "#{result[0]}: #{result[1]['hash']} #{result[2]}"
        if result[0] == "block"
          block = STORE.get_block(result[1]["hash"])
          @channel.push compile_block_haml(block)
        end
      rescue
        p $!
        puts *$@
      end
    end
  end

  def unbind
    puts "bitcoin server disconnected"
    EM.defer do
      sleep 10
      EM.connect(@host, @port, self.class, @host, @port, @channel)
    end
  end

end

EM.run do
  ws_host, ws_port = BB_CONFIG["websocket"].split(":")
  bc_host, bc_port = BB_CONFIG["command"].split(":")

  channel = EM::Channel.new

  EM.connect(bc_host, bc_port, BitcoinConnection, bc_host, bc_port, channel)

  EventMachine::WebSocket.start(:host => ws_host, :port => ws_port) do |ws|
    ws.onopen do |*a|
      puts "websocket client connected"
      sid = channel.subscribe {|msg| ws.send msg.to_json }
    end
    ws.onclose { puts "websocket client disconnected" }
  end

  puts "websocket listening on #{ws_host}:#{ws_port}"
end
