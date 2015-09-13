$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'fluent/test'
require 'fluent/plugin/in_zabbix_agent'
require 'json'
require 'time'
require 'timecop'
require 'tempfile'
require 'webrick'

# Disable Test::Unit
module Test::Unit::RunCount; def run(*); end; end
Test::Unit.run = true if defined?(Test::Unit) && Test::Unit.respond_to?(:run=)

AGENT_HOST = '127.0.0.1'
AGENT_PORT = 10050

JSOND_PORT = 20080
JSOND_DATA = {'foo' => 'bar'}

RSpec.configure do |config|
  config.before(:all) do
    Fluent::Test.setup
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

### servers ###

def wait_server_start(host, port)
  600.times do # timeout: 1 min
    begin
      TCPSocket.open(host, port).close
      break
    rescue
      sleep 0.1
    end
  end
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

  wait_server_start(AGENT_HOST, AGENT_PORT)
end
start_echod

def start_jsond
  logger = WEBrick::Log.new('/dev/null')
  server = WEBrick::HTTPServer.new(Port: JSOND_PORT, Logger: logger, AccessLog: logger)

  server.mount_proc('/') do |req, res|
    res.body = JSON.dump(JSOND_DATA)
  end

  Thread.start do
    server.start
  end

  wait_server_start('127.0.0.1', JSOND_PORT)
end
start_jsond
