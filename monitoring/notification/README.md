# SMS notification for neteye4

- home path of SMS module: /neteye/local/smsd/
- grant permissions to icinga user on spool folders
```
chown icinga:icinga -R /neteye/local/smsd/data/spool
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
