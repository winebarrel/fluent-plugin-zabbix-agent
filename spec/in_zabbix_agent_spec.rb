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
  let(:before_driver_run) { }

  let(:driver) do
    before_create_driver
    create_driver(fluentd_conf)
  end

  subject { driver.emits }

  before do
    before_driver_run
    driver.run
  end

  context 'when get zabbix items' do
    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
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
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n", "hostname"=>"my-host"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n", "hostname"=>"my-host"}],
      ]
    end
  end

  context 'when get zabbix items with tag' do
    let(:fluentd_conf) do
      default_fluentd_conf.merge(tag: 'zabbix.item2')
    end

    it do
      is_expected.to match_array [
        ["zabbix.item2", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item2", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when use items file' do
    let(:items_file) {
      Tempfile.open('in_zabbix_agent_spec_item_file')
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
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when use multiple items files' do
    let(:items_file1) {
      Tempfile.open('in_zabbix_agent_spec_item_file1')
    }

    let(:items_file2) {
      Tempfile.open('in_zabbix_agent_spec_item_file2')
    }

    let(:fluentd_conf) do
      {
        items_file: "{#{items_file1.path},#{items_file2.path}}",
        interval: 0,
      }
    end

    let(:before_create_driver) do
      items_file1.puts(JSON.dump("system.cpu.load[all,avg1]" => "load_avg1"))
      items_file1.flush
      items_file2.puts(JSON.dump("system.cpu.load[all,avg5]" => nil))
      items_file2.flush
    end

    after do
      items_file1.close
      items_file2.close
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when zabbix error' do
    let(:items) do
      {
        "system.cpu.load[all,avg1]" => "load_avg1",
        "system.cpu.load[all,avg5]" => nil,
        zabbix_error => nil,
      }
    end

    let(:error_messages) { [] }

    let(:before_driver_run) do
      allow(driver.instance.log).to receive(:warn) {|msg| error_messages << msg }
    end

    let(:expected_records) do
      [
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end

    shared_examples 'zabbix error' do
      it do
        is_expected.to match_array expected_records
        expect(error_messages).to eq ["#{zabbix_error}: #{zabbix_error}\n"]
      end
    end

    context "when ZBX_NOTSUPPORTED" do
      let(:zabbix_error) { "ZBX_NOTSUPPORTED\x00Invalid second parameter." }
      it_behaves_like 'zabbix error'
    end

    context "when ZBX_ERROR" do
      let(:zabbix_error) { "ZBX_ERROR\x00Invalid second parameter." }
      it_behaves_like 'zabbix error'
    end
  end

  context 'when unexpected error' do
    let(:zabbix_error) { "ZBX_ERROR\x00Invalid second parameter." }

    let(:items) do
      {
        "system.cpu.load[all,avg1]" => "load_avg1",
        "system.cpu.load[all,avg5]" => nil,
        zabbix_error => nil,
      }
    end

    let(:error_messages) { [] }

    let(:before_driver_run) do
      expect(driver.instance.log).to receive(:warn).with("#{zabbix_error}: #{zabbix_error}\n").and_raise('unexpected error')
      allow(driver.instance.log).to receive(:warn) {|msg| error_messages << msg }
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]

      expect(error_messages.first).to match /ZBX_ERROR\u0000Invalid second parameter\.: unexpected error/
    end
  end

  context 'when get zabbix item_{key,val}_key' do
    let(:fluentd_conf) do
      default_fluentd_conf.merge(
        item_key_key: 'key2',
        item_value_key: 'value2',
      )
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"key2"=>"load_avg1", "value2"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key2"=>"system.cpu.load[all,avg5]", "value2"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when record_key is Hash' do
    let(:items) do
      {
        "system.cpu.load[all,avg1]" => {"name"=>"load_avg1","source"=>"all"},
        "system.cpu.load[all,avg5]" => nil,
      }
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"name"=>"load_avg1", "source"=>"all", "value"=>"system.cpu.load[all,avg1]\n"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n"}],
      ]
    end
  end

  context 'when get zabbix items with allow_items_empty' do
    let(:items) { {} }

    let(:fluentd_conf) do
      default_fluentd_conf.merge(allow_items_empty: true)
    end

    it do
      is_expected.to be_empty
    end
  end

  context 'when get zabbix items with bulk/allow_items_empty' do
    let(:items) { {} }

    let(:fluentd_conf) do
      default_fluentd_conf.merge(
        allow_items_empty: true,
        bulk: true
      )
    end

    it do
      is_expected.to be_empty
    end
  end

  context 'when get zabbix items with hostname' do
    let(:fluentd_conf) do
      default_fluentd_conf.merge(
        include_hostname: true,
        hostname_key: 'hostname2'
      )
    end

    let(:before_create_driver) do
      allow_any_instance_of(Fluent::ZabbixAgentInput).to receive(:hostname) { 'my-host2' }
    end

    it do
      is_expected.to match_array [
        ["zabbix.item", 1432492200, {"key"=>"load_avg1", "value"=>"system.cpu.load[all,avg1]\n", "hostname2"=>"my-host2"}],
        ["zabbix.item", 1432492200, {"key"=>"system.cpu.load[all,avg5]", "value"=>"system.cpu.load[all,avg5]\n", "hostname2"=>"my-host2"}],
      ]
    end
  end
end
