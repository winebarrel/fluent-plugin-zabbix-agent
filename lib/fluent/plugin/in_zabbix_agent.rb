require 'fluent_plugin_zabbix_agent/version'

class Fluent::ZabbixAgentInput < Fluent::Input
  Fluent::Plugin.register_input('zabbix_agent', self)

  unless method_defined?(:log)
    define_method('log') { $log }
  end

  unless method_defined?(:router)
    define_method('router') { Fluent::Engine }
  end

  def initialize
    super
    require 'csv'
    require 'fileutils'
    require 'logger'
    require 'time'
    require 'addressable/uri'
    require 'aws-sdk'
  end

  config_param :agent_host, :string,  :default => '127.0.0.1'
  config_param :agent_port, :integer, :default => 10050
  config_param :interval,   :time,    :default => 60
  config_param :tag,        :string,  :default => 'zabbix.item'
  config_param :items,      :hash
  config_param :extra,      :hash,    :default => {}
  config_param :bulk,       :bool,    :default => false

  def initialize
    super
    require 'socket'
    require 'zabbix_protocol'
  end

  def configure(conf)
    super

    @items.keys.each do |key|
      value = @items[key]
      @items[key] = key if value.nil?
    end
  end

  def start
    super

    @loop = Coolio::Loop.new
    timer = TimerWatcher.new(@interval, true, log, &method(:fetch_items))
    @loop.attach(timer)
    @thread = Thread.new(&method(:run))
  end

  def shutdown
    @loop.watchers.each(&:detach)
    @loop.stop

    # XXX: Comment out for exit soon. Is it OK?
    #@thread.join
  end

  private

  def run
    @loop.run
  rescue => e
    log.error(e.message)
    log.error_backtrace(e.backtrace)
  end

  def fetch_items
    value_by_item = {}

    @items.each do |key, record_key|
      value = zabbix_get(key)
      value_by_item[record_key] = value
    end

    emit_items(value_by_item)
  end

  def zabbix_get(key)
    value = nil

    TCPSocket.open(@agent_host, @agent_port) do |sock|
      sock.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
      sock.write ZabbixProtocol.dump(key + "\n")
      sock.close_write
      value = ZabbixProtocol.load(sock.read)
    end

    value
  end

  def emit_items(value_by_item)
    time = Time.now

    records = value_by_item.map do |key, value|
      {key => value}
    end

    if @bulk
      bulk_record = records.inject({}) {|r, i| r.merge(i) }
      router.emit(@tag, time.to_i, bulk_record.merge(extra))
    else
      records.each do |rcrd|
        router.emit(@tag, time.to_i, rcrd.merge(extra))
      end
    end
  end

  class TimerWatcher < Coolio::TimerWatcher
    def initialize(interval, repeat, log, &callback)
      @callback = callback
      @log = log
      super(interval, repeat)
    end

    def on_timer
      @callback.call
    rescue => e
      @log.error(e.message)
      @log.error_backtrace(e.backtrace)
    end
  end # TimerWatcher
end # Fluent::ZabbixAgentInput
