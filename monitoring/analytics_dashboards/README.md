# Analytics dashboards overview

Here I will provide sample dashboards to present monitoring data within NetEye. The dashboards are build to represent data of different kind, from simple monitoring performance, to End User Monitoring (Alyvix) to various dashboards.

Dashboards are based on ITOA dashboarding infrastrucutre of NetEye. Requirements are therefore the dashboarding modules Grafana installed by default on NetEye 3 and NetEye 4

Some analytics dashboards require the [setup on NetEye of the ITOA streaming data collection infrastructure](../../itoa/)

## Provided Dashboards 

### ITOA custom dashboards
To be called from monitoring service (custom variable within service template)

- itoa_cust_hostalive.json         (itoa custom dashboard variable: cus0000005/host-hostalive
- itoa_cust_diskspace_by_host.json (itoa custom dashboard variable: cus0000010/service-diskspace-by-host


### Standalone dashboards
- generic_services_by_host.json Choose single command, single service and multiple Host. For each host a new graph is shown.
- [End User Monitoring - Alyvix](alyvix/)
