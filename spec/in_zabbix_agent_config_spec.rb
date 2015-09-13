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

  subject { create_driver(fluentd_conf).instance }

  context 'when default' do
    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to be_nil

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when default' do
    it do
      expect(driver.instance.agent_host).to eq '127.0.0.1'
      expect(driver.instance.agent_port).to eq 10050
      expect(driver.instance.interval).to eq 60
      expect(driver.instance.tag).to eq 'zabbix.item'
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to be_nil

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end

  context 'when not default' do
    let(:extra) { {"hostname" => "my-host"} }

    let(:fluentd_conf) do
      default_fluentd_conf.merge(
        agent_host: '127.0.0.2',
        agent_port: 10051,
        interval: 61,
        tag: 'zabbix.item2',
        extra: JSON.dump(extra),
        bulk: true
      )
    end

    it do
      expect(driver.instance.agent_host).to eq '127.0.0.2'
      expect(driver.instance.agent_port).to eq 10051
      expect(driver.instance.interval).to eq 61
      expect(driver.instance.tag).to eq 'zabbix.item2'
      expect(driver.instance.extra).to eq extra
      expect(driver.instance.bulk).to be_truthy
      expect(driver.instance.items_file).to be_nil

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
      expect(driver.instance.extra).to eq({})
      expect(driver.instance.bulk).to be_falsey
      expect(driver.instance.items_file).to eq items_file.path

      expect(driver.instance.items).to eq items.merge(
        "system.cpu.load[all,avg5]" => "system.cpu.load[all,avg5]"
      )
    end
  end
end
