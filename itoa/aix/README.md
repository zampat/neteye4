
# Introduction

The following collection of projects allows to collect performance data from IBM AIX at a higher frequency, than a polling approach might reach.

__Advice: the following how-to is work in progress and subject to further changes/improvements__

# Setup and software requirements

## Overview of related projects

- [Project site:](http://nmon.sourceforge.net/pmwiki.php?n=Site.Njmon)
- Project site on [`sourceforge`:](https://sourceforge.net/projects/nmon/files/)


## Software from OSS repositories

- AIX Collector binaries: [`njmon_aix_binaries_v21.zip`](https://sourceforge.net/projects/nmon/files/njmon_aix_binaries_v21.zip/download)
- Converter for Json file to inject performance data to influxdb: [`njmon_to_InfluxDB_injector_15.py`](https://sourceforge.net/projects/nmon/files/njmon_to_InfluxDB_injector_15.py/download)
- [Sample Grafana dashboard](https://sourceforge.net/projects/nmon/files/Grafana_Template_for_njmon_AIX_v3-1548086037850.json/download)

## Setup AIX data grabber

Compiled binary approach:
- Unzip `njmon_aix_binaries_v21.zip` and place binary for suitable AIX version 6.x or 7.x
- Define Path for Program code: `/usr/local/njmon/`
- Place Njmon binary and executable (755): i.e. `/usr/local/njmon/njmon_aix71_v22`
- Place job run script and set execution rights (755): i.e. `/usr/local/njmon/run_njmon_job.sh`
- Create output folder for Njmon job. Default: /var/log/njmon. This path is defined in: `run_njmon_job.sh`

```
# ls -la /usr/local/njmon/
total 3840
drwxr-xr-x    2 root     system          256 Jun  6 15:59 .
drwxr-xr-x    5 root     system          256 Jun  6 13:51 ..
-rwxr-xr-x    1 root     system       766811 May 20 23:37 njmon_aix71_v21
-rwxr-xr-x    1 root     system          862 Jun  6 16:34 run_njmon_job.sh
```

Adjust the output and archive path for collected perfdata in run_njmon_job.sh
i.e. /var/log/njmon/

Perform a test run and verify output in output path:

```
/usr/local/njmon/njmon_aix71_v21 -s 10 -c 5 -m /var/log/njmon/ -f
```

Contents in output path:
```
# ls -la /var/log/njmon/
total 432
drwxr-xr-x    2 njmon    system          256 Jun  6 16:45 .
drwxr-xr-x    6 bin      bin             256 Jun  6 13:58 ..
-rw-r--r--    1 root     system            0 Jun  6 16:45 db09_20190606_1645.err
-rw-r--r--    1 root     system       219162 Jun  6 16:45 db09_20190606_1645.json
```

### Setup of ssh key trust towards neteye

The aim is to synchronize all performance data-files (.json) to neteye via scp. For this the AIX system has to be trusted on NetEye.

1. Create a user on NetEye
2. Generate ssh key for this user on NetEye:
```
# useradd -d /var/log/njmon njmon
# su - njmon
# ssh-keygen -t rsa
```

Now trust the ssh key of your AIX system on NetEye, to allow login as user `njmon`
1. Get ssh public key from AIX user executing the script run_njmon_job.sh
On AIX as user executing the script (i.e. root):
```
# cat .ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2....
```
2. Allow this user (key) to login on NetEye as user `njmon`
On NetEye add this public key to file ".ssh/authorized_hosts" in user home of `njmon`
```
# cat /var/log/njmon/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2....
```
3. Test ssh from AIX towards NetEye
```
AIX:/>
# ssh njmon@neteyehost
Last login: Thu Jun  6 17:03:37 2019
-bash-4.2$
```

4. Register your neteye hostname in run_njmon_job.sh, variable "DST_NETEYE_HOST"

5. Register the cronjob as indicated sample in run_njmon_job.sh


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



# Setup and Configuration on NetEye

1. Validate the json file
```
# cat aix001.json | jq
```
 
2. Create the influxdb database
```
create database njmon
```

IF everything is working:
```
# cat aix001.json | python3 njmon_to_InfluxDB_injector_15.py
os_name:AIX os_base:AIX 7.1 os_long:AIX 7.1 TL4 sp5
arch:POWER8
mtm: 1234-AAA
serial_no: 21D6D17
{'host': 'aix001', 'os': 'AIX 7.1 TL4 sp5', 'os_name': 'AIX', 'os_base': 'AIX 7.1', 'architecture': 'POWER8', 'serial_no': 'abcdefg, 'mtm': '1234-AAA'}
```

## Configure job

1. Define directory for scripts: i.e.`/usr/local/njmon/`
2. Place `njmon_to_InfluxDB_injector_15.py` from above mentioned project
3. Place njmon_influx_injector.sh and set execution rights
```
[root@tue-lx-neteye4 njmon]# ll /usr/local/njmon/
total 16
drwxr-xr-x. 5 root root   82 Jun  6 15:14 influxdb
-rwxr-xr-x. 1 root root  869 Jun  6 16:36 njmon_influx_injector.sh
-rw-r--r--. 1 root root 5999 Jun  6 15:27 njmon_to_InfluxDB_injector_15.py
```

Define in njmon_influx_injector.sh your path variables:
NJMON_PERFDATA_PATH: create folder and `chown` to user njmon to allow any remote AIX writing

Configure processing job:
1. Define cronjob to process `njmon_influx_injector.sh`
```
# crontab -l
# AIX Performance data injector
*/5 * * * *     /usr/local/njmon/njmon_influx_injector.sh
```





