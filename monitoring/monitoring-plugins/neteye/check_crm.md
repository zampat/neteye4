# PCS Cluster Monitoring Script

Usage: Import CRM PCS Basket

Create file `/etc/sudoers.d/crm_mon`
```
icinga ALL=(ALL) NOPASSWD: /usr/sbin/crm_mon -1 -r -f
```
