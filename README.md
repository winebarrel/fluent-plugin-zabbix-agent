# fluent-plugin-zabbix-agent

Fluentd input plugin for Zabbix agent.

It gets items of zabbix using [passive check](https://www.zabbix.com/documentation/2.4/manual/appendix/items/activepassive#passive_checks).

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-zabbix-agent.svg)](http://badge.fury.io/rb/fluent-plugin-zabbix-agent)
[![Build Status](https://travis-ci.org/winebarrel/fluent-plugin-zabbix-agent.svg)](https://travis-ci.org/winebarrel/fluent-plugin-zabbix-agent)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-zabbix-agent'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-zabbix-agent

## Configuration

```apache
<source>
  type zabbix_agent

  #agent_host 127.0.0.1
  #agent_port 10050
  #interval 60
  #tag zabbix.item
  #item_key_key key
  #item_value_key value
  #extra {}
  #bulk false

  items {
    "system.cpu.load[all,avg1]": "load_avg1",
    "system.cpu.load[all,avg5]": "load_avg5",
    ...
  }
  # or
  #items_file /path/to/items.json
  # or
  #items_file /path/to/conf.d/items-*.json
</source>

```

## Usage

### Get zabbix items as multiple records

```apache
<source>
  type zabbix_agent
  extra {"hostname", "my-host"}
  items {
    "system.cpu.load[all,avg1]": "load_avg1",
    "system.cpu.load[all,avg5]": null
  }
</source>

```

```
2015-01-02 12:30:40 +0000 zabbix.item: {"key":"load_avg1","value":0.0,"hostname":"my-host"}
2015-01-02 12:30:40 +0000 zabbix.item: {"key":"system.cpu.load[all,avg5]","value":0.01,"hostname":"my-host"}
```

## Get zabbix items as a single record

```apache
<source>
  type zabbix_agent
  extra {"hostname", "my-host"}
  bulk true
  items {
    "system.cpu.load[all,avg1]": "load_avg1",
    "system.cpu.load[all,avg5]": null
  }
</source>

```

```
2015-01-02 12:30:40 +0000 zabbix.item: {"load_avg1":0.06,"system.cpu.load[all,avg5]":0.03,"hostname":"my-server"}
```
