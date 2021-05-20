## Prerequisites

1. Neteye 4.16
2. setup and configured Nats service on Neteye
3. setup and configured Tornado service , Tornado nats collector services and Tornado UI on neteye master
4. installed AX Etw Traxing and SQLDMV Monitor  version 0.5 or higher
5. installed and configured Zampat repository (please refer to <https://github.com/zampat/neteye4/blob/master/doc/050_community_configs_init.md>) on the neteye master

>Zampat repository is required as configuration is based on the Host template generic-passive-host and Service template generic-passive-service

## Icinga Directory Objects for EndPoint monitor

Configuration of neteye Icinga Directory Objects for EndPoint monitor

![define_data_fields](images/define_data_fields.png)

1. Create Data Fields (dummy_text and dummy_state)


![new_dummy_text_data_field](MonitoringEndpointGuide/images/new_dummy_text_data_field.png)

```
dummy_text :
Fieldname : dummy_text
Caption : Dummy Text
Data Type: String
Visibility: Visible

dummy_state :
Fieldname : dummy_state
Caption : Dummy State
Data Type: Number
```

### Command creation

#### keepalive_check:

![icinga_create_command_keepalive_check](MonitoringEndpointGuide/icinga_create_command_keepalive_check.png)

```
Command type: Plugin Check Command
Command name: keepalive_check
Command: /usr/lib64/neteye/monitoring/plugins/check_dummy
Timeout :60
```
```
Dummy State: 2
Dummy Text: No keepalive message received from host within defined timeout
```

![icinga_create_command_keepalive_check_state_arg](MonitoringEndpointGuide/icinga_create_command_keepalive_check_state_arg.png)

```
Argument name: state
Description : state
Value Type: String
Value: $dummy_state$
Position: 1
```

![icinga_create_command_keepalive_check_output_arg](MonitoringEndpointGuide/icinga_create_command_keepalive_check_output_arg.png)

```
Argument name: output_text
Description : output
Value Type: String
Value: $dummy_text$
Position: 2
``` 

#### monitordata_check

```
  Command type: Plugin Check Command
  Command name: monitordata_check
  Command: /usr/lib64/neteye/monitoring/plugins/check_dummy
  Timeout :60
```
```
  Dummy State: 2
  Dummy Text : No monitordata message received from host within defined timeout
```

![icinga_create_command_monitordata_check_output_arg](MonitoringEndpointGuide/icinga_create_command_monitordata_check_output_arg.png)

```
Argument name: state
Description : state
Value Type: String
Value: $dummy_state$
Position: 1
```

![icinga_create_command_monitordata_check_output_arg](MonitoringEndpointGuide/icinga_create_command_monitordata_check_output_arg.png)

```
Argument name: output_text
Description : output
Value Type: String
Value: $dummy_text$
Position: 2
``` 

### Create Service templates

#### generic_keepalive_service

![generic_keepalive_service_template](MonitoringEndpointGuide/generic_keepalive_service_template.png)

```
Main properties
  Name : generic_keepalive_service
  imports: generic-passive-service
  Check command: keepalive_check
```
```
Check execution
  check_interval = 1m
  retry_interval = 15s
  enable_active_checks = yes
```

#### generic_monitordata_service

![generic_monitordata_service_template](MonitoringEndpointGuide/generic_monitordata_service_template.png)

```
Main properties
  Name : generic_monitordata_service
  Imports : generic-passive-service
  Check command: keepalive_check
```
```
Check execution
  check_interval : 10m  
  retry_interval : 15s
  enable_active_checks : yes
```


## Setup for Nats messages

Messages are sent from agents to tornado_nats_json_collector via nats-server with publish-subscribe pattern: agent is a publisher and nats_json_collector on neteye is a subscriber. The subject for this publish-subscriber couple is called topic (now *<agent\_monitor\_alive\.topic\>*) and it has to be different from subjects used by other publisher/subscriber like e.g. telegraf because of diffent message formats. 
Conventional topic names have "tornado_nats_json." as first level of the hierarchy.

https://docs.nats.io/nats-concepts/subjects#subject-hierarchies

### Configuration of nats user and permissions

Define permission for ax and sql agents on nats server \<user\>

In */neteye/shared/nats-server/conf/permissions.d/<user\>.conf* file add the new section e.g.

```
  AGENT_MONITOR_ALIVE_METRICS = 
  {
    publish = "tornado_nats_json.foo.>"
  }
```

At this point in */neteye/shared/nats-server/conf/users.d/\<user\>.conf* add the new permission

```
  {
    user: "\<user\>", 
    permissions: $AGENT_MONITOR_ALIVE_METRICS
  }
```

### Setup topic for agents 

on axetwtracing and sqldmvmonitor config files topic configuration is in the tornado section 

```
#defines the nats channel to send keepalive & monitoring data infos to neteye server, disabled by default
#[output.tornado]
#topic = "tornado_nats_json.<topic>" #mandatory, it represents the subject on nats-server (configured in tornado_nats_json_collector topics on neteye)
#keepaliveInterval = 5 #interval in seconds for keepalive message, if omitted default value is 5 seconds;
#monitordataInterval = 30 #interval in seconds for monitordata message, if omitted default value is 30 seconds;
#hostnameformat="fullqualified" #default is "fullqualified", otherwise put "hostonly"
#tornado_dedicated_connection: all the following settings must be used to open a dedicated connection for tornado messages (in case destination addresses and/or certifcate are different)
#address = "TORNADO-NATS-ADDRESS" #optional (see tornado_dedicated_connection above)
#secure = true #optional (see tornado_dedicated_connection above) set as true if TLS is needed, if omitted default value is false
#tls_cert = "<PATHVALUE>\\<filename>.crt.pem" #optional (see tornado_dedicated_connection above) certificate path
#tls_key = "<PATHVALUE>\\<filename>.key.pem"  #optional (see tornado_dedicated_connection above) private key path
```

### Configuration of tornado\_nats\_json\_collector service

https://github.com/WuerthPhoenix/tornado/blob/develop/tornado/nats_json_collector/README.md

#### Topics definition

The nats\_json\_collector service listens only to events of defined topics: create *\<agent\_monitor\_alive\.topic\>\.json* files in */neteye/shared/tornado\_nats\_json\_collector/topics* with the following syntax

```
  {
    "nats_topics": [<agent_monitor_alive.topic>],
    "collector_config": {
      "event_type": "${event_type}",
      "payload": {
        "header": "${header}",
        "body": "${body}"
      }
    }
  }
```

>*collector_config* defines inner transformation rules from agents'messages to tornado messages and in case you intend to modify it you have to modify tornado filters & rules accordingly

#### Permissions on topic files

```
Chown tornado <topic>.json
Chgrp tornado <topic>.json
Chmod g+r-x <topic>.json
Chmod +rw <topic>.json
Chmod o-xrw <topic>.json
```

>*tornado* group must have read rights on file *\<agent\_monitor\_alive\.topic\>\.json*

#### 

Restart and test status of nats\_json\_collector service

```
systemctl restart tornado_nats_json_collector.service
systemctl status tornado_nats_json_collector.service
```

## Tornado

https://github.com/WuerthPhoenix/tornado

### Configuration of Tornado rules and filters for Agents using Tornado UI

Adding filter for <itoafilter> and new ruleset <create_and_process_events>
  
![tornado_ui_itoafilter](MonitoringEndpointGuide/tornado_ui_itoafilter.png)

```
{
  "description": "filters all events of type \"monitoring.events.message\"",
  "active": true,
  "filter": {
    "type": "AND",
    "operators": [
      {
        "type": "equals",
        "first": "${event.type}",
        "second": "monitoring.events.keepalive"
      }
    ]
  }
}
```

![tornado_ui_rulesset](MonitoringEndpointGuide/tornado_ui_rulesset.png)

Add Rule keepalive

>Name: keepalive  
>position: 1  
>description: keepalive message  
>active: true  
>continue after: true  

```
where:
{
  "type": "AND",
  "operators": [
    {
      "type": "equals",
      "first": "${event.payload.header.id}",
      "second": 1
    }
  ]
}

with:
{
  "instance": {
    "from": "${event.payload.header.instance}",
    "regex": {
      "type": "Regex",
      "match": "(\\$.+)*$",
      "group_match_idx": 0,
      "all_matches": false
    },
    "modifiers_post": [
      {
        "type": "ReplaceAll",
        "find": "$",
        "replace": "",
        "is_regex": false
      }
    ]
  }
}

action:
[
  {
    "id": "smart_monitoring_check_result",
    "payload": {
      "action_name": "create_and_or_process_service_passive_check_result",
      "check_result": {
        "exit_status": "0",
        "plugin_output": "message received from ${event.payload.header.instance} ${event.payload.header.description}",
        "service": "${event.payload.header.host}!${event.payload.header.instance} keepalive",
        "type": "Service"
      },
      "host": {
        "address": "${event.payload.header.host}",
        "imports": "generic-passive-host",
        "object_name": "${event.payload.header.host}",
        "object_type": "Object",
        "vars": {
          "created_by": "tornado",
          "rulename": "monitoring.events.keepalive"
        }
      },
      "service": {
        "host": "${event.payload.header.host}",
        "imports": "generic_keepalive_service",
        "object_name": "${event.payload.header.instance} keepalive",
        "object_type": "Object",
        "vars": {
          "agentname": "${event.payload.header.agent}",
          "created_by": "tornado",
          "datasource": "${event.payload.header.details.datasource}",
          "instancename": "${_variables.instance}",
          "rulename": "monitoring.events.keepalive",
          "version": "${event.payload.header.details.major}.${event.payload.header.details.minor}.${event.payload.header.details.build}"
        }
      }
    }
  }
]
```

Add Rule monitordata

>Name: monitordata  
>position: 2  
>description: monitordata message  
>active: true  
>continue after: true  

```
where:
{
  "type": "AND",
  "operators": [
    {
      "type": "equals",
      "first": "${event.payload.header.id}",
      "second": 2
    }
  ]
}

with:
{
  "instance": {
    "from": "${event.payload.header.instance}",
    "regex": {
      "type": "Regex",
      "match": "(\\$.+)*$",
      "group_match_idx": 0,
      "all_matches": false
    },
    "modifiers_post": [
      {
        "type": "ReplaceAll",
        "find": "$",
        "replace": "",
        "is_regex": false
      }
    ]
  }
}

action:
[
  {
    "id": "smart_monitoring_check_result",
    "payload": {
      "action_name": "create_and_or_process_service_passive_check_result",
      "check_result": {
        "exit_status": "${event.payload.body.exit_status}",
        "performance_data": "${event.payload.body.performance_data}",
        "plugin_output": "message received from ${event.payload.header.instance} ${event.payload.header.description}",
        "service": "${event.payload.header.host}!${event.payload.header.instance} monitordata",
        "type": "Service"
      },
      "host": {
        "address": "${event.payload.header.host}",
        "imports": "generic-passive-host",
        "object_name": "${event.payload.header.host}",
        "object_type": "Object",
        "vars": {
          "created_by": "tornado",
          "rulename": "monitoring.events.monitordata"
        }
      },
      "service": {
        "host": "${event.payload.header.host}",
        "imports": "generic_monitordata_service",
        "object_name": "${event.payload.header.instance} monitordata",
        "object_type": "Object",
        "vars": {
          "agentname": "${event.payload.header.agent}",
          "created_by": "tornado",
          "instancename": "${_variables.instance}",
          "rulename": "monitoring.events.monitordata"
        }
      }
    }
  }
]
```
