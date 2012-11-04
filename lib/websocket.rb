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

EM.run do
  ws_host, ws_port = BB_CONFIG["websocket"].split(":")
  bc_host, bc_port = BB_CONFIG["command"].split(":")

  CHANNEL = EM::Channel.new

  Bitcoin::Network::CommandClient.connect(bc_host, bc_port) do
    on_connected { p 'c'; request("monitor", "block") }
    on_block do |blk|
      block = STORE.get_block(blk['hash'])
      p block.hash
      CHANNEL.push compile_block_haml(block)
      # TODO: fix caching properly
      cache_dir = File.join(Rails.root, "tmp/cache/")
      FileUtils.rm_rf cache_dir
      FileUtils.mkdir cache_dir
    end
  end

  EventMachine::WebSocket.start(:host => ws_host, :port => ws_port) do |ws|
    ws.onopen do |*a|
      puts "websocket client connected"
      sid = CHANNEL.subscribe {|msg| ws.send msg.to_json }
    end
    ws.onclose { puts "websocket client disconnected" }
  end

  puts "websocket listening on #{ws_host}:#{ws_port}"
end
