# Tornado Testcase Overview

- Enable the Tornado email collector to collect incoming events

```
Tax code 160 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01).
```

## Configuration instructions  

1. Configuration of email receiver server, user and procmail
2. Configuration of tornado
- Configure tornado mail collector
- Configure tornado rule for specific email event

## Use case

Send an email via email to tornado collector
Example email:
```
Tax code 541 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01).
```


## Configuration of email receiver server, user and procmail

Verify the Unix Socket path where tornado email collector is listening for incoming emails.
Path of configuration file: /neteye/shared/tornado/conf/collectors/email/email_collector.toml

Configure for the local mail user a .procmail file in the home path:
cat /home/eventgw/.procmailrc 
```
SHELL=/bin/sh
:0
| /usr/bin/socat - /var/run/tornado_email_collector/email.sock 2>&1
```

## Configuration of tornado

Ready for first email delivery test:

- Enable the logger level to "debug" 
- Restart tornado_email_collector.service
- Install mutt and send a test email
- Start listening for incoming emails

```
1. Edit /neteye/shared/tornado/conf/collectors/email/email_collector.toml
2. # systemctl restart tornado_email_collector.service
3. # echo "Tax code 541 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01)." | mutt -s "SAP IDOC Error" eventgw@localhost
4. # journalctl -u tornado_email_collector -f
```

If an active default archive rule esists, you should find the archived event in the archive folder /neteye/shared/tornado/data/archive/all/:

```
Sample archive rule:
/neteye/shared/tornado/conf/rules.d/001_all_emails.json 
{
    "name": "all_emails",
    "description": "This matches all emails",
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
      "WITH": {}
    },
    "actions": [
      {
        "id": "Logger",
        "payload": {
          "type": "${event.type}",
          "subject": "${event.payload.subject}"
        }
      }
    ]
}
```

Line in archive file:
```
{"created_ms":1572448123732,"type":"email","payload":{"from":"root <root@neteye.zampat.lab>","attachments":[],"date":1572448123,"to":"eventgw@localhost.zampat.lab","subject":"SAP IDOC Error","body":"Tax code 541 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01).\n\n","cc":""}}
```


### Configure tornado rule for specific email event

1. Define new Tornado Rule
2. Validate config: 
3. Restart service: 
4. Trigger event: Send email
5. Check logs

```
1. /neteye/shared/tornado/conf/rules.d/003_email_sap_idoc_error.json
2. /usr/bin/tornado check
3. systemctl restart tornado
4. # echo "Tax code 541 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01)." | mutt -s "SAP IDOC Error" eventgw@localhost
5. journalctl -u tornado.service -f
```



Configure the API permissions for the Icinga2 executor:
icinga2_client_executor.toml

Tracing the collected message:
Get from logs the received log file the received json message, write it into a file and pass it to the "tornado-send-event" command:

```
echo '{"type":"email","created_ms":1572456429212,"payload":{"date":1572456429,"subject":"SAP IDOC Error","from":"root <root@neteye4osmc.zampat.lab>","attachments":[],"to":"eventgw@localhost.zampat.lab","cc":"","body":"Tax code 541 may only contain one assignment line (Message no. FF173) while creating Sample document (T.Code F-01).\n\n"}}' > received_message.json

# tornado-send-event ./received_message.json
```






















