# Tornado collectors

## Email collector

Configure a `procmail` command for an event gateway user i.e. `eventgw`
```
# cat /home/eventgw/.procmailrc
SHELL=/bin/sh
:0
| /usr/bin/socat - /var/run/tornado_email_collector/email.sock 2>&1

```

### Troubleshooting hint

Enable debug level and write into dedicated file. 
Then restart service.
```
# cat /neteye/shared/tornado/conf/collectors/email/email_collector.toml
[logger]
...
level = "debug"
...
file_output_path = "/neteye/shared/tornado/log//email_collector.log"

```
