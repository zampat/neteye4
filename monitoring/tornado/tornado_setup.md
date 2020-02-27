# Tornado collectors

## Email collector

Configure `procmail` to accept emails for host. If hostname does not correspond to result from `hostnamectl` register the fqdn in main.cf of postfix:
```
# cat /etc/postfix/main.cf
...
# INTERNET HOST AND DOMAIN NAMES
#
# The myhostname parameter specifies the internet hostname of this
# mail system. The default is to use the fully-qualified domain name
# from gethostname(). $myhostname is used as a default value for many
# other configuration parameters.
#
myhostname = cluster_neteye.mydomain.lan
...
```

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
