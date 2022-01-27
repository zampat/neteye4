# SMS notification for neteye4

- restore provided basket
```
icingacli director basket restore < Director-Basket_teams-notifications_56f58bd.json
```
- install teams notification script in /neteye/shared/icinga2/conf/icinga2/scripts/
```
cp teams-notification.py /neteye/shared/icinga2/conf/icinga2/scripts/
chmod 755 /neteye/shared/icinga2/conf/icinga2/scripts/teams-*
```
Define a variable field and user template:
```
template User "microsoft-teams-template" {
    vars.teams_webhook_url = "https://mydomain.webhook.office.com/webhookb2/XXX"
}
``` 
