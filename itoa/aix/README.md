
# Introduction

The following collection of projects allows to collect performance data from IBM AIX at a higher frequency, than a polling approach might reach.

__Advice: the following how-to is work in progress and subject to further changes/improvements__

# Setup and software requirements

## Overview

Project site:
http://nmon.sourceforge.net/pmwiki.php?n=Site.Njmon

Project site on sourceforge:
https://sourceforge.net/projects/nmon/files/


## Software from OSS repositories

- AIX Collector binaries: [njmon_aix_binaries_v21.zip](https://sourceforge.net/projects/nmon/files/njmon_aix_binaries_v21.zip/download)
- Converter fo Json file to inject performance data to influxdb: [njmon_to_InfluxDB_injector_15.py](https://sourceforge.net/projects/nmon/files/njmon_to_InfluxDB_injector_15.py/download)
- [Sample Grafana dashboard](https://sourceforge.net/projects/nmon/files/Grafana_Template_for_njmon_AIX_v3-1548086037850.json/download)

## Setup AIX data grapper

Pre-comiled Binary approach:
Unzip njmon_aix_binaries_v21.zip and place binary for suitable AIX version 6.x or 7.x

Activate the job via cronjob defining the frequency and number of iterations to run. 
Note: The JSON file remains "open" as long as the projcess is running.

## NetEye performance data handling and influx writer

```
yum install --enablerepo=epel python36.x86_64 python36-pip-8.1.2-8.el7.noarch python36-virtualenv.noarch
```

### Configuration of virtualenv

Create a virtualenv (named influxdb)
```
cd /opt/neteye
virtualenv-3.6 influxdb
```

Activate the virtualenv in order to be able to use it with the following command
```
source $PWD/influxdb/bin/activate
```

You will see that now the prompt of your CLI is preceded by the name of the virtualenv (influxdb)
```
(influxdb) [root@neteye $pwd]#
```

To install the missing module, requests, issue the following command, making sure that you're still in the virtualenv (you will spot its name at the beginning of your CLI)
```
pip3 install influxdb
```



# Configuration on NetEye




$ ./njmon_aix71_v21 -m perfdata/ -f

$ ps aux | grep njm
ca001139 24445074  0.0  0.0 1176 1784      - A    14:30:25  0:00 ./njmon_aix71_
ca001139 24313952  0.0  0.0  236  248  pts/4 A    14:31:26  0:00 grep njm

$ cd perfdata/


__Attention: Json is not valid as long not completed all iterations!__
 
 
1. Validate the json file
```
# cat ap371pho_20190530_1430.json | jq
```
 
2. Create the influxdb database
```
create database njmon
```



Then its working:

[root@neteye4zapa nmon]# cat ap371pho_20190530_1430.json | python3 njmon_to_InfluxDB_injector_15.py
os_name:AIX os_base:AIX 7.1 os_long:AIX 7.1 TL4 sp5
arch:POWER8
mtm: 1234-AAA
serial_no: 21D6D17
{'host': 'aix001', 'os': 'AIX 7.1 TL4 sp5', 'os_name': 'AIX', 'os_base': 'AIX 7.1', 'architecture': 'POWER8', 'serial_no': 'abcdefg, 'mtm': '1234-AAA'}
