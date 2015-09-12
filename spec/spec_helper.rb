$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'fluent/test'
require 'fluent/plugin/in_zabbix_agent'
require 'json'
require 'time'
require 'timecop'
require 'tempfile'

# Disable Test::Unit
module Test::Unit::RunCount; def run(*); end; end
Test::Unit.run = true if defined?(Test::Unit) && Test::Unit.respond_to?(:run=)

AGENT_HOST = '127.0.0.1'
AGENT_PORT = 10050

RSpec.configure do |config|
  config.before(:all) do
    Fluent::Test.setup
    start_echod
    Timecop.freeze(Time.parse('2015/05/24 18:30 UTC'))
  end
end

def create_driver(options = {})
  additional_options = options.select {|k, v| v }.map {|key, value|
    "#{key} #{value}"
  }.join("\n")

  fluentd_conf = <<-EOS
type zabbix_agent
#{additional_options}
  EOS

  Fluent::Test::OutputTestDriver.new(Fluent::ZabbixAgentInput, 'test.default').configure(fluentd_conf)
end

def start_echod
  Thread.start do
    Socket.tcp_server_loop(AGENT_PORT) do |sock, client_addrinfo|
      begin
        IO.copy_stream(sock, sock)
      ensure
        sock.close
      end
    end
  end

  600.times do # timeout: 1 min
    begin
      TCPSocket.open(AGENT_HOST, AGENT_PORT).close
      break
    rescue
      sleep 0.1
    end
  end
end
