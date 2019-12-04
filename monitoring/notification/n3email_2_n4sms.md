# How to to send sms from neteye 4 via neteye 3 eventhandler

## Enable sendmail on neteye 3
https://www.ghacks.net/2009/06/05/make-sendmail-accept-mail-from-external-sources/

In /etc/mail/sendmail.mc change
```
DAEMON_OPTIONS(`Family=inet,  Name=MTA-v4, Addr=127.0.0.1, Port=smtp')dnl
to
DAEMON_OPTIONS(`Family=inet,  Name=MTA-v4, Port=smtp')dnl
```

# Forward relay emails to neteye 4 

Direct relay from neteye 4 postfix
https://serverfault.com/questions/257637/postfix-to-relay-mails-to-other-smtp-for-particular-domain

```
[root@p-neteye4-a postfix]# tail /etc/postfix/main.cf
...
# RELAY MAPPINGS PER DOMAIN
transport_maps = hash:/etc/postfix/transport


[root@p-neteye4-a postfix]# tail /etc/postfix/transport
...
#Send emails to neteye 3 eventhandler
eventgw@p-neteye-lc.rtl2.de smtp:p-neteye-lc.rtl2.de

# postmap /etc/postfix/transport
```


# NetEye 3 Eventhandler rule

Create a rule in EventHandler matching the senders address of NetEye4 (or other conditions). The Actions should look like this:
```
 /usr/local/bin/sendsms +4915164519590 @SUBJECT@
```
