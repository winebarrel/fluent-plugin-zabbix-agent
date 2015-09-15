describe 'Fluent::ZabbixAgentInput#configure (error)' do
  context 'when not pass item and items_file' do
    it do
      expect {
        create_driver
      }.to raise_error 'One of "items" or "items_file" is required'
    end
  end

  context 'when pass item and items_file' do
    let(:items) do
      {
        "system.cpu.load[all,avg1]" => "load_avg1",
        "system.cpu.load[all,avg5]" => nil,
      }
    end

    it do
      expect {
        create_driver(
          items: '{"key": null}',
          items_file: '/path/to/item.json'
        )
      }.to raise_error %!It isn't possible to specify both of items" and "items_file"!
    end
  end

  context 'when items is empty' do
    let(:items_file1) {
      Tempfile.open('in_zabbix_agent_spec_item_file1')
    }

    let(:items_file2) {
      Tempfile.open('in_zabbix_agent_spec_item_file2')
    }

    after do
      items_file1.close
      items_file2.close
    end

    it do
      expect {
        create_driver(
          items_file: "{#{items_file1.path},#{items_file2.path},/path/to/not/found}",
        )
      }.to raise_error '"items" or "items_file" is empty'
    end
  end

  context 'when items is empty with allow_items_empty' do
    let(:items) { {} }

    it do
      expect {
        create_driver(
          items: items,
          allow_items_empty: true
        )
      }.to_not raise_error
    end
  end
end
