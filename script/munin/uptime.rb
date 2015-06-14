#!/usr/bin/env ruby1.9.1

require 'eventmachine'
require 'bitcoin'

NETWORK = $0.split("_", 3)[-1]
CONFIG = "#{ENV['HOME']}/#{NETWORK}/#{NETWORK}.conf"

defaults = Bitcoin::Network::Node::DEFAULT_CONFIG
options = Bitcoin::Config.load(defaults, :all)
options = Bitcoin::Config.load_file(options, CONFIG, :all)

if ARGV[0] == "config"
  puts "graph_title Bitcoin Node Uptime [#{NETWORK}]"
  puts "graph_vlabel [#{NETWORK}]"
  puts "graph_category bitcoin"
  puts "graph_scale no"
  puts "uptime.label Uptime (in min)"
  exit 0
end

EM.run do
  host, port = *options[:command]
  port = port.to_i
  Bitcoin::Network::CommandClient.connect(host, port) do
    on_response do |cmd, data|
      unless cmd == "monitor"
        puts "uptime.value #{data['uptime']}"
        EM.stop
      end
    end
    on_connected do
      request("info")
    end
  end
end


