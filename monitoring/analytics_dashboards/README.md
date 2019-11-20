# Analytics dashboards overview

Here I will provide sample dashboards to present monitoring data within NetEye. The dashboards are build to represent data of different kind, from simple monitoring performance, to End User Monitoring (Alyvix) to various dashboards.

Dashboards are based on ITOA dashboarding infrastructure of NetEye. Requirements are therefore the dashboarding modules Grafana installed by default on NetEye 3 and NetEye 4

Some analytics dashboards require the [setup on NetEye of the ITOA streaming data collection infrastructure](../../itoa/)

## Provided Dashboards 

### ITOA custom dashboards
To be called from monitoring service (custom variable within service template)
__Note: since NetEye v 4.7 the URL must specify the alias "d" and you need to prefix "../d/"__

- `itoa_cust_hostalive.json`         [Preview](./itoa_cust_hostalive.png) (itoa custom dashboard path: `../d/cus0000005/host-hostalive`
- `itoa_cust_diskspace_by_host.json` [Preview](./itoa_cust_diskspace_by_host.png) (itoa custom dashboard variable: `../d/cus0000010/service-diskspace-by-host`
- `itoa_cust_interfaces.json`        [Preview](./itoa_cust_interfaces.png) (itoa custom dashboard variable: `../d/cus0000011/interfaces-traffic`



### Standalone dashboards
- generic_services_by_host.json Choose single command, single service and multiple Host. For each host a new graph is shown.
- [End User Monitoring - Alyvix](alyvix/)
