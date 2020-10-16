# Tornado - event processing engine

Tornado is the module for flexible event processing in NetEye. The core of Tornado represents the event processing engine configurable by hierarchical set of rules. Those rules are structured in a hierarchical way, in order to setup processing trees to respect events coming from various input channels or to structure events according various usecases.

To get a in depth introduction to Tornado consult the user guide withing NetEye 4 or [visit the project website on github](https://github.com/WuerthPhoenix/tornado). Tornado is published according the Apache license and therefore the entire source code is open.

## Setup of tornado

Tornado is shipped as EXTRA package with the lastest versions of NetEye 4.14 (and later) with the core subscription. Therefore to install Tornado you need to follow the indications in the NetEye 4 user guid for installing additional software. For those desiring installing Tornado on a plain Linxu environment, follow the instructions on the project website on github.

Notes related the setup of Tornado collectors can be found in folder: "tornado_setup"


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
  - filter to accpt all incoming emails
  \ rules
    - rule to accept all events and archive into archive folder according event type "email"
    - sample rule to match according a simple regex and perform monitoring action: create/update host, create/update service and define monitoring status
\ snmptrap
  - filter to accpt all incoming snmptraps
  \ rules
    - rule to accept all events and archive into archive folder according event type "snmptrapd"
    - sample rule to match according a simple regex and perform monitoring action: create/update host, create/update service and define monitoring status
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
```


## Usecase: SNMP-Trap event processing

The scenario consists in the assumption a remote device, such as a network devices, is sending an event message to Tornado. The Tornado snmp-trap collector accepts the message and a filter rule for snmptrap files forwards the event to a dedicated archive rule. Then the event message is stored within the archive folder.

Step 1: Send an snmptrap to tornado (Note: "localhost" is the node where tornado resides)

```
# snmptrap -v 2c -c public localhost '' 1.3.6.1.4.1.8072.2.3.0.1 SNMPv2-MIB::sysName.0 s "hostname1" DISMAN-EVENT-MIB::sysUpTimeInstance s "Uptime 180 Days" 1.3.6.1.4.1.8072.2.3.2.1 i 100 
```

According the installed Filter rules and mathing rules, the incoming trap had been matched by rule "archive_all". According those settings, the action "archive" for archive_type = snmptrad should have been called. To verify the definition of this archive type verify the file (you just edited it): /neteye/shared/tornado/conf/archive_executor.toml

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

Extend the ruleset' to match:
- the hostname from 'SNMPv2-MIB::sysName.0'
- the days of uptime from 'DISMAN-EVENT-MIB::sysUpTimeInstance'
- Extra points: verify value 'NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate' < 100

We consider defining a new rule according the provided samples in rule "sample_regex_with_monitoring_action".

Define the WITH section to match the OID "DISMAN-EVENT-MIB::sysUpTimeInstance". Please note the above JSON structure: you need to address the entire path, therefore event.payload.oids.DISMAN-EVENT-MIB::sysUpTimeInstance. Life would be too easy when just copy-paste the name ... you need to define the OID within  " " as it contains spaces or other non-word characters. Remember also to escape the " with \".

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
Define the Event Type: "snmptrapd" and copy the entire payload {} into the Test window and "Run Test".

<image of Tornado test window>


Now proceed defining a suitable action. According the available "action" types, we use now an action definition to forward a result to monitoring module Icinga2. The action "monitoring" consists of 3 sub-actions:
- host_creation_payload:  define a new host object if not created, yet
- service_creation_payload: define a new service object if not created, yet
- process_check_result_payload: define the status, status description and (optional) performance data

Here comes the rule's Action definition:
```
[
  {
    "id": "monitoring",
    "payload": {
      "action_name": "create_and_or_process_service_passive_check_result",
      "host_creation_payload": {
        "address": "127.0.0.1",
        "imports": "generic-passive-host",
        "object_name": "${event.payload.oids.\"SNMPv2-MIB::sysName.0\".content}",
        "object_type": "Object",
        "vars": {
          "created_by": "tornado"
        }
      },
      "process_check_result_payload": {
        "exit_status": "0",
        "performance_data": [],
        "plugin_output": "Hearbeat value: ${event.payload.oids.\"DISMAN-EVENT-MIB::sysUpTimeInstance\".content}",
        "service": "${event.payload.oids.\"SNMPv2-MIB::sysName.0\".content}!Heartbeat",
        "type": "Service"
      },
      "service_creation_payload": {
        "host": "${event.payload.oids.\"SNMPv2-MIB::sysName.0\".content}",
        "imports": "generic-passive-service",
        "object_name": "Heartbeat",
        "object_type": "Object",
        "vars": {
          "created_by": "tornado"
        }
      }
    }
  }
]
```


When performing the Test again, enabling the option "Enable execution of actions", event the action section is executed and therefore a new host and service object defined in monitoring (if not exists) and the status is defined: OK with the output "Hearbeat value: 100".

