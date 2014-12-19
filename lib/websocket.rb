require 'eventmachine'
require 'json'
require 'em-websocket'
require 'ostruct'

include ActionView::Helpers::NumberHelper
include ApplicationHelper
include Rails.application.routes.url_helpers

def compile_block_haml(block)
  ctx = OpenStruct.new(blk: block)
  template = File.read(File.join(Rails.root, "app/views/blocks/_blk.html.haml"))
  res = Haml::Engine.new(template).render(ctx)
  "<tr>#{res.gsub!("\n", '')}</tr>"
end

def compile_mempool_haml(tx, priority, type)
  ctx = OpenStruct.new(tx: tx, priority: priority, params: { type: type })
  template = File.read(File.join(Rails.root, "app/views/blocks/_mempool.html.haml"))
  res = Haml::Engine.new(template).render(ctx)
  "<tr id='mempool_#{tx.hash}' class='#{type}'>#{res.gsub!("\n", '')}</tr>"
end

File.open(File.join(Rails.root, "tmp/pids/websocket.pid"), "w") {|f| f.write Process.pid }

EM.run do
  ws_host, ws_port = BB_CONFIG["websocket"].split(":")
  bc_host, bc_port = BB_CONFIG["command"].split(":")

  CHANNEL = EM::Channel.new
  CLIENTS = {}
  SUBSCRIPTIONS = {}

  log = Bitcoin::Logger.create(:websocket, :debug)

  Bitcoin::Node::CommandClient.connect(bc_host, bc_port) do
    on_connected do
      log.info { "Connected to bitcoin node" }

      request("monitor", channel: "block") do |blk, height|
        next  if blk.keys == ["id"]
        block = STORE.get_block(blk['hash'])
        log.info { "new block: #{block.height} #{block.hash}" }
        CHANNEL.push ["new_block", {height: block.height, json: block.to_hash,
            partial: compile_block_haml(STORE.db[:blk][id: block.id])}]
        log.debug { "pushed block #{block.height}" }
        # TODO: fix caching properly
        cache_dir = File.join(Rails.root, "tmp/cache/")
        FileUtils.rm_rf cache_dir
        FileUtils.mkdir_p cache_dir
      end

      [:accepted, :rejected, :doublespend].each do |type|
        request("monitor", channel: "mempool_#{type}") do |data|
          next  if data.keys == ["id"]

          data["created_at"] = Time.parse(data["created_at"]).to_i  if data["created_at"]
          data["updated_at"] = Time.parse(data["updated_at"]).to_i  if data["updated_at"]
          data[:payload] = data["payload"].htb

          log.info { "mempool #{type}: #{data['hash']} (#{data['priority']})" }
          tx = MEMPOOL.get(data['hash'])
          CHANNEL.push ["mempool_#{type}", { id: tx.id, hash: tx.hash,
              partial: compile_mempool_haml(tx, data["priority"], type) }]
        end
      end

      request("monitor", channel: "mempool_seen") do |data|
        next  if data.keys == ["id"]
        log.info { "mempool seen: #{data['hash']} (#{data['times_seen']})" }
        CHANNEL.push ["mempool_seen", data]
        CHANNEL.push ["mempool_seen_#{data['id']}", data]
      end

      request("monitor", channel: "mempool_confirmed") do |data|
        next  if data.keys == ["id"]
        log.info { "mempool confirmed: #{data['hash']}" }
        CHANNEL.push ["mempool_confirmed", data]
        CHANNEL.push ["mempool_confirmed_#{data['id']}", data]
      end

    end
  end

  EventMachine::WebSocket.start(:host => ws_host, :port => ws_port) do |ws|
    sid = nil

    ws.onopen do
      port, host = *Socket.unpack_sockaddr_in(ws.get_peername)
      log.info { "#{host}:#{port} client connected" }
      SUBSCRIPTIONS[[host, port]] = []
      sid = CHANNEL.subscribe {|msg|
        # port, host = *Socket.unpack_sockaddr_in(ws.get_peername)
        ws.send msg.to_json  if SUBSCRIPTIONS[[host, port]].include?(msg[0])
      }
      CLIENTS[sid] = [host, port]
      CHANNEL.push ["client_count", CLIENTS.size]
    end

    ws.onclose do
      host, port = *CLIENTS[sid]
      log.info { "#{host}:#{port} client disconnected" }
      CHANNEL.unsubscribe(sid)
      CLIENTS.delete(sid)
      CHANNEL.push ["client_count", CLIENTS.size]
    end

    ws.onmessage do |msg|
      port, host = *Socket.unpack_sockaddr_in(ws.get_peername)
      log.info { "#{host}:#{port} client subscribed to #{msg} channel" }
      SUBSCRIPTIONS[[host, port]] << msg
      ws.send(["client_count", CLIENTS.size].to_json) if msg == "client_count"
    end
  end

  log.info { "websocket listening on #{ws_host}:#{ws_port}" }
end
