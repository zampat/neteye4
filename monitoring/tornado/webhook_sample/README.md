# Tornado Test case Overview

- Enable the Tornado webhook collector to collect incoming events via Rest API
  - A JSON-formatted curl call allows us to send payload into tornado for matching via defined rules and possible action execution
- Rule definition for incoming events 
  - Verify the event type (event.type): "generic_event“
  - Define a script action where required parameters are passed to script from event payload
  - Feature of executed script:
    - Create a new host based on specific template via icingacli
    - Create a new service based on specific template via icingacli
    - Set the Status, Output to this service in monitoring

Sample json-event sent to tornado:
```
{"event":{"type":"generic_event", "created_ms":1550000000000, "payload": { "servicename": "Service2", "state": "2", "output": "Major_problem" }}, "process_type":"Full"}
```

## Implementation details

Place script create_host_live.sh in folder of your preference i.e.: /neteye/shared/tornado/exercise/
```
# Sample script execution
/neteye/shared/tornado/exercise/create_host_live.sh ${event.payload.servicename} ${event.payload.state} ${event.payload.output}
```

Configuration of tornado rule
- Install the provided rule 003_create_live_hosts.json in /neteye/shared/tornado/conf/rules.d/
- Validate config: /usr/bin/tornado --config-dir /neteye/shared/tornado/conf check
- Restart service: systemctl restart tornado

## Test rule

Send an event via tornado webhook call 
```
# curl -sS -H "content-type: application/json" -X POST -d '{"event":{"type":"generic_event", "created_ms":1550000000000, "payload": { "servicename": "Service1", "state": "1", "output": "Running_without_replica" }}, "process_type":"Full"}' http://localhost:4748/api/send_event | jq
```
Evaluate output:
```
{
  "event": {
    "type": "generic_event",
    "created_ms": 1550000000000,
    "payload": {
      "state": "1",
      "servicename": "Service1",
      "output": "Running_without_replica"
    }
  },
  "result": {
    "type": "Rules",
    "rules": {
      "rules": {
        "create_live_hosts": {
          "rule_name": "create_live_hosts",
          "status": "Matched",
          "actions": [
            {
              "id": "script",
              "payload": {
                "script": "/neteye/shared/tornado/exercise/create_host_live.sh Service1 1 Running_without_replica"
              }
            }
          ],
          "message": null
        }
      },
      "extracted_vars": {}
    }
  }
}

```
