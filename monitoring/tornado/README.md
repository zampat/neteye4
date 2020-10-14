# Tornado for NetEye 4

Sample tornado filters and rules collection

## Setup of tornado

Setup Tornado packages as indicated in NetEye user guide "Installing Additional Modules". Once done continue configuring the daemon and collectors:

Notes related the setup of tornado collectors can be found in folder: tornado_setup


## Configure sample Tornado rules

If starting from a new "blank" Tornado setup, it is convenient to boost your getting-started with a set of sample tornado rules.
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


## Perform SNMPTRAP Test

Send a trap

```
# snmptrap -v 2c -c public localhost '' 1.3.6.1.4.1.8072.2.3.0.1 SNMPv2-MIB::sysName.0 s "hostname1" DISMAN-EVENT-MIB::sysUpTimeInstance s "Uptime 180 Days" 1.3.6.1.4.1.8072.2.3.2.1 i 100 
```

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

Extend the ruleset to match:
- the hostname from "SNMPv2-MIB::sysName.0"
- the days of uptime from "DISMAN-EVENT-MIB::sysUpTimeInstance"
- extra: verify value "NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate" < 100

Rule WITH:
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
Rule Action:
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



