## Create the Director Automation Business Process

Patch the Icingaweb module BusienssProcess to add a director hook for import automation.
Apply the provided patch:
```
# cd /usr/share/icingaweb2/modules/businessprocess
# patch -p 6 < /<patch_to_git>/neteye4/monitoring/configurations/director/businessprocess_automation/icingaweb_director_businessprocess_automation.patch
```

## Create Import Definition and Synch-Rule for Director

Import provided Basket
Director-Basket_Automation_BusinessProcess.json
