# SMS notification for neteye4

- home path of SMS module: /neteye/local/smsd/
- grant permissions to icinga user on spool folders
```
chown icinga:icinga -R /neteye/local/smsd/data/spool
chmod 755 /neteye/local/smsd/data/spool
chmod 777 /neteye/local/smsd/data/spool/outgoing
```
- diff /usr/bin/smssend with provided file
- restore provided basket
```
icingacli director basket restore < Director-Basket_SMS_Notification.json
```
- install SMS notification script in /neteye/shared/icinga2/conf/icinga2/scripts/
```
cp sms-host-notification.sh sms-service-notification.sh /neteye/shared/icinga2/conf/icinga2/scripts/
chmod 755 /neteye/shared/icinga2/conf/icinga2/scripts/sms-*
```
Patch the `smssend` binary:
```
grep out /usr/bin/smssend
```

SMS-Queue files in the outgoing queue.
```
FILE=`mktemp /neteye/local/smsd/data/spool/outgoing/send_XXXXXX`
```
 
