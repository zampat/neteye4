## Configure tornado rules

### Troubleshooting hints

Enable debug log
```
# cat /neteye/shared/tornado/conf/tornado.toml
[logger]
...
level = "debug"
...
file_output_path = "/neteye/shared/tornado/log/tornado.log"
```

Restart service    
```
# systemctl restart tornado.service
```

Send event to an active collector and retrieve event in debug log:
```
[2020-01-14][16:24:46][tornado_common::actors::json_event_reader][DEBUG] JsonReaderActor - received json message: [{"type":"email","created_ms":1579015486546,"payload":{"attachments":[],"to":"eventgw@neteye.mydomain.lan","cc":"","from":"root <root@neteye.mydomain.lan>","subject":"zapa test email","date":1579015486,"body":"this is an email coming in\n\n"}}]
```

### Create a simple archive rule:
```
{
  "description": "This is a test mail from zapa.",
  "continue": true,
  "active": true,
  "constraint": {
    "WHERE": {
      "type": "AND",
      "operators": [
        {
          "type": "equal",
          "first": "${event.type}",
          "second": "email"
        }
      ]
    },
    "WITH": {
      "subject": {
        "from": "${event.payload.subject}",
        "regex": {
          "match": "zapa\\s+",
          "group_match_idx": 0
        }
      }
    }
  },
  "actions": [
    {
      "id": "Logger",
      "payload": {
        "type": "${event.type}",
        "subject": "${event.payload.subject}",
        "temperature:": "${_variables.subject}"
      }
    }
  ]
}
```

Validate configuration:
```
# tornado check
```

Then restart tornado, send the event again an check the log file:
```
# systemctl restart tornado.service

# tailf one_events.log
{"type":"email","created_ms":1579016269560,"payload":{"subject":"zapa test email","attachments":[],"cc":"","body":"this is an email coming in\n\n","date":1579016269,"to":"eventgw@neteye.mydomain.lan","from":"root <root@neteye.mydomain.lan>"}}
```
