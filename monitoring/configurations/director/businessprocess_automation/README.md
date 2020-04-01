## Create the Director Automation Business Process

Patch the Icingaweb module BusinessProcess to add a director hook for import automation.
Apply the provided patch:
```
# cd /usr/share/icingaweb2/modules/businessprocess
# patch -p 6 < /<patch_to_git>/neteye4/monitoring/configurations/director/businessprocess_automation/icingaweb_director_businessprocess_automation.patch
```

## Create Import Definition and Synchronization-Rule for Director

Import provided Basket: [Director-Basket_Automation_BusinessProcess.json](https://github.com/zampat/icinga2-monitoring-templates/tree/master/baskets/import_automation)
This Basket file is locate in project [icinga2-monitoring-templates](https://github.com/zampat/icinga2-monitoring-templates)
