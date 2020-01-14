## Configure tornado rule with Icinga2 action

Having completed the setup and a simple archive rule, we can extend this concept to set a status in icinga2 monitoring.

Assume having a host "event_results" and a passive service "test event status"

- copy previous rule into a new file with HIGHER number i.e. 002- and 003-
- define action of type icinga and filter for desired host/service

### Define rule action

Dump of action section of previous rule
```
"actions": [
    {
      "id": "icinga2",
      "payload": {
        "icinga2_action_name": "process-check-result",
        "icinga2_action_payload": {
          "exit_status": "1",
          "plugin_output": "${event.payload.subject}",
          "filter": "host.name==\"event_results\" && service.name==\"test event status\"",
          "type": "Service"
        }
      }
    }
  ]

```

Validate configuration, then restart tornado, send the event again an check the log file:
```
# tornado check
# systemctl restart tornado.service
```
After sending the event the tornado log reports the following action result:
```
[2020-01-14][16:55:04][tornado_engine::executor::icinga2][DEBUG] Icinga2 API request completed successfully. Response body: b"{\"results\":[{\"code\":200.0,\"status\":\"Successfully processed check result for object 'event_results!test event status'.\"}]}"
```
