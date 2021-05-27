# Analytics dashboards overview

Here I will provide sample dashboards to present monitoring data within NetEye. The dashboards are build to represent data of different kind, from simple monitoring performance, to End User Monitoring (Alyvix) to various dashboards.

Dashboards are based on ITOA dashboarding infrastructure of NetEye. Requirements are therefore the dashboarding modules Grafana installed by default on NetEye 3 and NetEye 4

Some analytics dashboards require the [setup on NetEye of the ITOA streaming data collection infrastructure](../../itoa/)

## Provided Dashboards 

### ITOA custom dashboards
To be integrated as ITOA custom dashboard into monitoring view, the relative url to the dashboard must be configured
__Details for the configuration in NetEye 4 user guide, chapter "ITOA" > "Custom Dashboards for Hosts and Services".__
__Note: since NetEye v 4.7 the URL must specify the alias "d" and you need to prefix "../d/"__
__Note: the Grafana authentication integration requires to pass all arguments via authentication proxy: Here an example of URL encoding:__
```
./analytics/analyticsdashboard?src=%2Fneteye%2Fanalytics%2Fproxy%2Fdashboard%2F..%2Fd%2Fcus0000005%2Fhost-hostalive%3Fvar-hostname%3Dclu-02%26var-command%3Dhostalive%26orgId%3D1%26var-limit%3D50%26var-page%3D1%26kiosk%3Dtv%26theme%3Dlight
```

- `itoa_cust_hostalive.json`         [Preview](./itoa_cust_hostalive.png) (url: `../d/cus0000005/host-hostalive`
- `generic_services.json` 	     [Preview](./itoa_cust_diskspace.png) (url: `../d/cus0000010/generic_services`
- `itoa_cust_cpu.json` 	             [Preview](./itoa_cust_diskspace.png) (url: `../d/cus0000020/service-cpu`
- `itoa_cust_load.json`               (url: `../d/cus0000021/service-load`
- `itoa_cust_memory.json` 	     [Preview](./itoa_cust_diskspace.png) (url: `../d/cus0000030/service-memory`
- `itoa_cust_memory_win.json` 	      (url: `../d/cus0000031/service-memory-win`
- `itoa_cust_diskspace.json`         [Preview](./itoa_cust_diskspace.png) (url: `../d/cus0000040/service-diskspace`
- `itoa_cust_disks_win.json`          (url: `../d/cus0000041/service-diskspace-win`
- `itoa_cust_interfaces.json`        [Preview](./itoa_cust_interfaces.png) (url: `../d/cus0000011/interfaces-traffic`




### Standalone dashboards
- generic_services_by_host.json Choose single command, single service and multiple Host. For each host a new graph is shown.
- [End User Monitoring - Alyvix](alyvix/)
