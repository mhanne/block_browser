#!/usr/bin/env ruby1.9.1

require 'eventmachine'
require 'bitcoin'

NETWORK = $0.split("_", 3)[-1]
CONFIG = "#{ENV['home']}/#{NETWORK}/#{NETWORK}.conf"

defaults = Bitcoin::Network::Node::DEFAULT_CONFIG
options = Bitcoin::Config.load(defaults, :all)
options = Bitcoin::Config.load_file(options, CONFIG, :all)

if ARGV[0] == "config"
  puts "graph_title Bitcoin Node Connections [#{NETWORK}]"
  puts "graph_vlabel [#{NETWORK}]"
  puts "graph_category bitcoin"
  puts "conn_total.label Total Connections"
  puts "conn_in.label Incoming Connections"
  puts "conn_out.label Outgoing Connections"
  puts "conn_new.label New Connections"
  exit 0
end

EM.run do
  host, port = *options[:command]
  port = port.to_i
  Bitcoin::Network::CommandClient.connect(host, port) do
    on_response do |cmd, data|
      unless cmd == "monitor"
	      c = data["connections"]
        puts "conn_total.value #{c['established']}"
        puts "conn_in.value #{c['incoming']}"
        puts "conn_out.value #{c['outgoing']}"
        puts "conn_new.value #{c['connecting']}"
        EM.stop
      end
    end
    on_connected do
      request("info")
    end
  end
end


