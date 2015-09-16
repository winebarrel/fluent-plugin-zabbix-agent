describe 'Fluent::ZabbixAgentInput#configure' do
  let(:items) do
    {
      "system.cpu.load[all,avg1]" => "load_avg1",
      "system.cpu.load[all,avg5]" => nil,
    }
  end

  let(:default_fluentd_conf) { {items: JSON.dump(items)} }
  let(:fluentd_conf) { default_fluentd_conf }
  let(:before_create_driver) { }

  let(:driver) do
    before_create_driver
    create_driver(fluentd_conf)
  end

  subject { driver.instance }

  context 'when default' do
    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.item_key_key).to eq 'key'
      expect(driver.instance.item_value_key).to eq 'value'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to be_nil
      expect(driver.instance.allow_items_empty).to be_falsey
      expect(driver.instance.include_hostname).to be_falsey
      expect(driver.instance.hostname_key).to eq 'hostname'

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when record_keykey is Hash' do
    {
      "system.cpu.load[all,avg1]" => {"key" => "load_avg1", "source" => "all"},
      "system.cpu.load[all,avg5]" => nil,
    }

    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.item_key_key).to eq 'key'
      expect(driver.instance.item_value_key).to eq 'value'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to be_nil
      expect(driver.instance.allow_items_empty).to be_falsey
      expect(driver.instance.include_hostname).to be_falsey
      expect(driver.instance.hostname_key).to eq 'hostname'

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when not default' do
    let(:extra) do
      {
        "hostname" => "my-host",
        "hostname2" => "my-host2",
      }
    end

    let(:fluentd_conf) do
      default_fluentd_conf.merge(
        agent_host: '127.0.0.2',
        agent_port: 10051,
        interval: 61,
        tag: 'zabbix.item2',
        item_key_key: 'key2',
        item_value_key: 'value2',
        extra: JSON.dump(extra),
        bulk: true,
        allow_items_empty: true,
        include_hostname: true,
        hostname_key: 'hostname2'
      )
    end

    let(:before_create_driver) do
      allow_any_instance_of(Fluent::ZabbixAgentInput).to receive(:hostname) { 'my-host2' }
    end

    it do
      expect(driver.instance.agent_host).to eq '127.0.0.2'
      expect(driver.instance.agent_port).to eq 10051
      expect(driver.instance.interval).to eq 61
      expect(driver.instance.tag).to eq 'zabbix.item2'
      expect(driver.instance.item_key_key).to eq 'key2'
      expect(driver.instance.item_value_key).to eq 'value2'
      expect(driver.instance.extra).to eq extra
      expect(driver.instance.bulk).to be_truthy
      expect(driver.instance.items_file).to be_nil
      expect(driver.instance.allow_items_empty).to be_truthy
      expect(driver.instance.include_hostname).to be_truthy
      expect(driver.instance.hostname_key).to eq 'hostname2'

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when pass items_file' do
    let(:items_file) {
      Tempfile.open('in_zabbix_agent_spec_item_file')
    }

    let(:fluentd_conf) {
      {items_file: items_file.path}
    }

    let(:before_create_driver) do
      items_file.puts(JSON.dump(items))
      items_file.flush
    end

    after do
      items_file.close
    end

    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.item_key_key).to eq 'key'
      expect(driver.instance.item_value_key).to eq 'value'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to eq items_file.path
      expect(driver.instance.allow_items_empty).to be_falsey
      expect(driver.instance.include_hostname).to be_falsey
      expect(driver.instance.hostname_key).to eq 'hostname'

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when pass items_file as url' do
    let(:items_file) { "http://127.0.0.1:#{JSOND_PORT}" }
    let(:fluentd_conf) { {items_file: items_file} }

    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.item_key_key).to eq 'key'
      expect(driver.instance.item_value_key).to eq 'value'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to eq items_file
      expect(driver.instance.items).to eq JSOND_DATA
      expect(driver.instance.allow_items_empty).to be_falsey
      expect(driver.instance.include_hostname).to be_falsey
      expect(driver.instance.hostname_key).to eq 'hostname'
    end
  end
end
