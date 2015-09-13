describe Fluent::ZabbixAgentInput do
  let(:items) do
    {
      "system.cpu.load[all,avg1]" => "load_avg1",
      "system.cpu.load[all,avg5]" => nil,
    }
  end

  let(:default_fluentd_conf) do
    {
      items: JSON.dump(items),
      interval: 0,
    }
  end

  let(:fluentd_conf) { default_fluentd_conf }
  let(:before_create_driver) { }

  let(:driver) do
    before_create_driver
    create_driver(fluentd_conf)
  end

  subject { driver.emits }

  before do
    driver.run
  end

  context 'when get zabbix items' do
    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"load_avg1"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"system.cpu.load[all,avg5]"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when get zabbix items as a single record' do
    let(:fluentd_conf) do
      default_fluentd_conf.merge(bulk: true)
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {
          "load_avg1"=>"system.cpu.load[all,avg1]\n",
          "system.cpu.load[all,avg5]"=>"system.cpu.load[all,avg5]\n",
        }]
      ]
    end
  end

  context 'when get zabbix items with extra' do
    let(:extra) { {"hostname" => "my-host"} }

    let(:fluentd_conf) do
      default_fluentd_conf.merge(extra: JSON.dump(extra))
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"load_avg1"=>"system.cpu.load[all,avg1]\n", "hostname"=>"my-host"}],
        ["zabbix.item", 1432492200, {"system.cpu.load[all,avg5]"=>"system.cpu.load[all,avg5]\n", "hostname"=>"my-host"}],
      ]
    end
  end

  context 'when get zabbix items with tag' do
    let(:extra) { {"hostname" => "my-host"} }

    let(:fluentd_conf) do
      default_fluentd_conf.merge(tag: 'zabbix.item2')
    end

    it do
      is_expected.to match_array [
        ["zabbix.item2", 1432492200, {"load_avg1"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item2", 1432492200, {"system.cpu.load[all,avg5]"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when use items file' do
    let(:items_file) {
      Tempfile.open('in_zabbix_agent_spec')
    }

    let(:fluentd_conf) do
      {
        items_file: items_file.path,
        interval: 0,
      }
    end

    let(:before_create_driver) do
      items_file.puts(JSON.dump(items))
      items_file.flush
    end

    after do
      items_file.close
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"load_avg1"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"system.cpu.load[all,avg5]"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end
end
