require 'fluent/input'
require 'fluent_plugin_zabbix_agent/version'

class Fluent::ZabbixAgentInput < Fluent::Input
  Fluent::Plugin.register_input('zabbix_agent', self)

  unless method_defined?(:log)
    define_method('log') { $log }
  end

  unless method_defined?(:router)
    define_method('router') { Fluent::Engine }
  end

  config_param :agent_host,        :string,  :default => '127.0.0.1'
  config_param :agent_port,        :integer, :default => 10050
  config_param :interval,          :time,    :default => 60
  config_param :tag,               :string,  :default => 'zabbix.item'
  config_param :item_key_key,      :string,  :default => 'key'
  config_param :item_value_key,    :string,  :default => 'value'
  config_param :items,             :hash,    :default => nil
  config_param :items_file,        :string,  :default => nil
  config_param :extra,             :hash,    :default => {}
  config_param :bulk,              :bool,    :default => false
  config_param :allow_items_empty, :bool,    :default => false
  config_param :include_hostname,  :bool,    :default => false
  config_param :hostname_key,      :string,  :default => 'hostname'

  def initialize
    super
    require 'socket'
    require 'zabbix_protocol'
    require 'json'
    require 'open-uri'
  end

  def configure(conf)
    super

    if @items.nil? and @items_file.nil?
      raise Fluent::ConfigError, 'One of "items" or "items_file" is required'
    elsif @items and @items_file
      raise Fluent::ConfigError, %!It isn't possible to specify both of items" and "items_file"!
    end

    if @items_file
      @items = {}

      if @items_file =~ %r{\A(https?|ftp)://}
        file = open(@items_file, &:read)
        json = JSON.load(file)
        @items.update(json) if json
      else
        Dir.glob(@items_file) do |path|
          file = File.read(path)
          json = JSON.load(file)
          @items.update(json) if json
        end
      end
    end

    if @items.empty? and not @allow_items_empty
      raise Fluent::ConfigError, '"items" or "items_file" is empty'
    end

    @items.keys.each do |key|
      value = @items[key]
      @items[key] = key if value.nil?
    end

    if @include_hostname
      @extra.update(@hostname_key => hostname)
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
    super
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
      begin
        value = zabbix_get(key)

        if value =~ /\AZBX_(NOTSUPPORTED|ERROR)\x00/
          log.warn("#{key}: #{value}")
        else
          value_by_item[record_key] = value
        end
      rescue => e
        log.warn("#{key}: #{e.message}")
        log.warn_backtrace(e.backtrace)
      end
    end

    unless value_by_item.empty?
      emit_items(value_by_item)
    end
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
    if @bulk
      records = value_by_item.map do |key, value|
        {key => value}
      end

      bulk_record = records.inject({}) {|r, i| r.merge(i) }
      router.emit(@tag, Fluent::Engine.now, bulk_record.merge(extra))
    else
      records = value_by_item.map do |key, value|
        if key.is_a?(Hash)
          key.merge(@item_value_key => value)
        else
          {@item_key_key => key, @item_value_key => value}
        end
      end

      records.each do |rcrd|
        router.emit(@tag, Fluent::Engine.now, rcrd.merge(extra))
      end
    end
  end

  def hostname
    `hostname`.strip
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
