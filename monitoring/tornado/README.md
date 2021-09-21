# Tornado - event processing engine

Tornado is the module for flexible event processing in NetEye. The core of Tornado represents the event processing engine configurable by hierarchical set of rules. Those rules are structured in a hierarchical way, in order to setup processing trees to respect events coming from various input channels or to structure events according various use case.

To get a in depth introduction to Tornado consult the user guide withing NetEye 4 or [visit the project website on github](https://github.com/WuerthPhoenix/tornado). Tornado is published according the Apache license and therefore the entire source code is open.

## Setup of tornado

Tornado is shipped as Preview Software with the latest versions of NetEye 4.15 (and later) and can be installed from the Repository "neteye-extras". The activation of the modules does not require any additional subscription, as shipped within the core subscription. To install Tornado you need to follow the indications in the NetEye 4 user guide for installing additional software. For those desiring installing Tornado on a plain Linux environment, follow the instructions on the project website on [github](https://github.com/WuerthPhoenix/tornado).

Notes related the setup of Tornado collectors can be found in folder: "tornado_setup".


## Configure Tornado with sample rules

In this place some sample rules for Tornado are provided that allow to cover you some simple requirements for event monitoring: 
- collect events and archive all events by collector channel (event source)
- compare some content within the event message according a pattern
- perform a monitoring action if previous pattern matches: define/update an Icinga Object status information

If starting from a new "blank" Tornado setup, it is simply possible to boost your getting-started with the provided set of sample tornado rules.
Those roles consists of a simple rule structure:
```
- filter to accept all incoming events
\ email
  - filter for incoming emails collected by Tornado service: "tornado_email_collector"
  \ rules
    - rule to accept all events and archive into archive folder according event type "email"
    - sample rule to match according a simple regex and perform monitoring action: create/update host, create/update service and define monitoring status
\ snmptrap
  - filter for incoming snmptraps collected by `snmptrapd` (configuration in /neteye/shared/snmptrapd/)
  \ rules
    - rule to accept all events and archive into archive folder according event type "snmptrapd"
    - sample rule to match according a simple regex and perform monitoring action: create/update host, create/update service and define monitoring status
\ webhooks
  - filter for Webhook HTTP call collected by from "tornado_webhook_collector" service
  \ hsg - Host - Service Generator
  - filter for Webhook HTTP call for ID "hsg"
  \ rules
    - all archive rule. Action "Archive" of Archive executor ${event.type}
    - create_only_new_host_object
    - monitoring_update_icinga_object_status
    - monitoring_create_update_icinga_object_status
```

### Install sample tornado rules

To install the set of default rules place the content of "draft_001/*" into folder "/neteye/shared/tornado/conf/drafts/draft_001/"
```
cp -r draft_001/* /neteye/shared/tornado/conf/drafts/draft_001/
chown -R tornado:tornado /neteye/shared/tornado/conf/drafts/draft_001/*
```

Define the Archive executors according the defined Archive events:
```
# cat /neteye/shared/tornado/conf/archive_executor.toml
base_path =  "/neteye/shared/tornado/data/archive/"
default_path = "/default/default.log"
file_cache_size = 10
file_cache_ttl_secs = 1

[paths]
one = "all/one_events.log"
email = "email/all_events.log"
snmptrapd = "snmptrap/all_events.log"
hsg = "webhooks/hsg/all_hsg_events.log"
```


## Use case: SNMP-Trap event processing

The scenario consists in the assumption a remote device, such as a network devices, is sending an event message to Tornado. The Tornado snmp-trap collector accepts the message and a filter rule for snmptrap files forwards the event to a dedicated archive rule. Then the event message is stored within the archive folder.

Step 1: Send an snmptrap to tornado (Note: "localhost" is the node where tornado resides)

```
# snmptrap -v 2c -c public localhost '' 1.3.6.1.4.1.8072.2.3.0.1 SNMPv2-MIB::sysName.0 s "hostname1" DISMAN-EVENT-MIB::sysUpTimeInstance s "Uptime 180 Days" 1.3.6.1.4.1.8072.2.3.2.1 i 100 
```

According the installed Filter rules and matching rules, the incoming trap had been matched by rule "archive_all". According those settings, the action "archive" for `archive_type = snmptrad` should have been called. To verify the definition of this archive type verify the file (you just edited it): /neteye/shared/tornado/conf/archive_executor.toml

Identify the last (or increase number ) archived snmp trap:
```
# tail -n 1 /neteye/shared/tornado/data/archive/snmptrap/all_events.log | jq
{
  "created_ms": 1602689610143,
  "payload": {
    "protocol": "UDP",
    "src_port": "35942",
    "dest_ip": "127.0.0.1",
    "oids": {
      "SNMPv2-MIB::sysName.0": {
        "content": "hostname1",
        "datatype": "STRING"
      },
      "SNMPv2-MIB::snmpTrapOID.0": {
        "datatype": "OID",
        "content": "NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification"
      },
      "DISMAN-EVENT-MIB::sysUpTimeInstance": {
        "content": "Uptime 180 Days",
        "datatype": "STRING"
      },
      "NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate": {
        "content": "100",
        "datatype": "INTEGER"
      }
    },
    "PDUInfo": {
      "errorstatus": 0,
      "messageid": 0,
      "errorindex": 0,
      "community": "public",
      "notificationtype": "TRAP",
      "requestid": 1356546780,
      "receivedfrom": "UDP: [127.0.0.1]:35942->[127.0.0.1]:162",
      "version": 1,
      "transactionid": 13
    },
    "src_ip": "127.0.0.1"
  },
  "type": "snmptrapd"
}
```

## Extending the rule and matching of 

Extend the rules to match:
- the hostname from `SNMPv2-MIB::sysName.0`
- the days of uptime from `DISMAN-EVENT-MIB::sysUpTimeInstance`
- Extra points: verify value `NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate' < 100`

We consider defining a new rule according the provided samples in rule "sample_regex_with_monitoring_action".

Define the WITH section to match the OID `DISMAN-EVENT-MIB::sysUpTimeInstance`. Please note the above JSON structure: you need to address the entire path, therefore `event.payload.oids.DISMAN-EVENT-MIB::sysUpTimeInstance`. Life would be too easy when just copy-paste the name ... you need to define the OID within  " " as it contains spaces or other non-word characters. Remember also to escape the " with \".

Here it goes:
```
{
  "type": "AND",
  "operators": [
    {
      "type": "regex",
      "regex": ".*Days.*",
      "target": "${event.payload.oids.\"DISMAN-EVENT-MIB::sysUpTimeInstance\".content}"
    }
  ]
}
```

### Test your condition

Now your next incoming Snmp-Trap should match the rule. Verify this using the "Test Window"!
Define the Event Type: `snmptrapd` and copy the entire payload {} into the Test window and "Run Test".

<image of Tornado test window>

# Tornado for NetEye 4

## Setup of tornado

Setup Tornado packages as indicated in NetEye user guide "Installing Additional Modules". Once done continue configuring the daemon and collectors:


Here comes the rule's Action definition:
```
[
  {
    "id": "smart_monitoring_check_result",
    "payload": {
      "check_result": {
        "exit_status": "1",
        "plugin_output": "Output message"
      },
      "host": {
        "address": "127.0.0.1",
        "check_command": "hostalive",
        "object_name": "host_snmptrap_demo",
        "vars": {
          "location": "Bozen"
        }
      },
      "service": {
        "check_command": "dummy",
        "object_name": "SNMPTRAP Demo"
      }
    }
  }
]
```


When performing the Test again, enabling the option "Enable execution of actions", event the action section is executed and therefore a new host and service object defined in monitoring (if not exists) and the status is defined: OK with the output "Heartbeat value: 100".

## Use case: Webhook Event call

The webhook represents a very universal and efficient way to structure data and transmit the contents to Tornado to create monitoring objects and update its status.

This example will make use of the rules to create a new monitoring Object in Director without automatically creating the Objects in Icinga. Within the payload all data for defining the object is provided.

__First define a webhook collector called `hsg`: Host-Service Generator__

The webhooks are defined within the configurations directory of the webhook collector service:
- ID defining the event
- Token, to validate incoming event body
- event_type as the type name
- payload json object
```
# cat /neteye/shared/tornado_webhook_collector/conf/webhooks/host_service_generator.json
{
  "id": "hsg",
  "token": "neteye_s3cr3t",
  "collector_config": {
    "event_type": "hsg",
    "payload": {
       "data": "${@}"
    }
  }
}
```
Once defined restart the webhook collector service.

A simple webhook collector event could look like this:
```
curl http://httpd.neteyelocal/tornado/webhook/event/hsg?token=neteye_s3cr3t -H "content-type: application/json" -X POST -d '{ "host_name": "host3", "host_address": "127.0.0.1", "host_template": "generic-host", "host_displayname": "Host 3",  "state": "1", "output": "Running_without_replica" }'
```

Sample call from remote host:
  ```
  curl --insecure https://myhost.mydomain/tornado/webhook/event/event-id?token=jO8nFg3yTTGu -H "content-type: application/json" -X POST -d '{ "message": "hello world", "status": "1" }' -vvv
  ```
[Setup tornado collectors email, snmptrap, webhook](tornado_setup.md)


## Configure Tornado rules

- [Configure a simple tornado rule to archive incoming events](tornado_rule_simple.md)
- [Extend tornado rule by Icinga2 action](tornado_rule_icinga.md)
