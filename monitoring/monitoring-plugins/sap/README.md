# SAP Monitorig via RFCGuide

## Introduction

SAP provides the possibility to run commands/abap scripts via RFC. In this section I will introduce an open-source framework to setup a monitoring via SAP NetWeaver RFC calls.
 
## Setup of SAP envirionment

The monitoring will be based on Python3 using the [PyRFC framework](https://sap.github.io/PyRFC/index.html).


Instrucitons for setup:
- Get SAP NWRFCSDK from SAP portal using you customer's account: Downlod archive for environment "linux x86_64"
- [Unzip and install the nwrfcsdk in /usr/local/sap/](https://sap.github.io/PyRFC/install.html#sap-nw-rfc-sdk-installation)
- Publish the nwrfcsdk sap libs using ld:
```
[root@neteyedewzr ~]# cat /etc/ld.so.conf.d/nwrfcsdk.conf
# include nwrfcsdk
/usr/local/sap/nwrfcsdk/lib
```
Execute the following command to reload linker run-time bindings:
```
ldconfig
```

## Setup of Python 3.6 envirionment

Requirement: install epel repo
```
yum --enablerepo=epel install python36-pip.noarch python36-virtualenv.noarch
```

Get a copy of the [pyrfc project](https://github.com/SAP/PyRFC) and in particular an appropriate release [from the release page](https://github.com/SAP/PyRFC/releases). The scripts where developed and tested with version 1.9.93:
```
wget https://github.com/SAP/PyRFC/releases/download/1.9.93/pyrfc-1.9.93-cp36-cp36m-linux_x86_64.whl
``` 

Setup a python3 virtualenv and install pyrfc project (N.B. currently the path of the virtualenv should be exactly `/opt/neteye/saprfc`) :
```
virtualenv-3.6 /opt/neteye/saprfc
source /opt/neteye/saprfc/bin/activate
(saprfc) [root@neteyedewzr neteye]#
(saprfc) [root@neteyedewzr neteye]# pip3.6 freeze
(saprfc) [root@neteyedewzr neteye]# pip3.6 install pyrfc-1.9.93-cp36-cp36m-linux_x86_64.whl
(saprfc) [root@neteyedewzr neteye]# deactivate
```

## Setup for Neteye Monitoring

1. Import the basket into your neteye instance: it defines a service template `sap_controller_service_template` and a
a command `check_sap_rfc`:

```sh
icingacli director basket restore < basket_sap_rfc_monitoring.json
```

2. copy `sap_python_wrapper.sh` under `PluginContribDir + /saprfc/old_perl_scripts/"`
3. copy `check_sap_python.py` under `/neteye/shared/monitoring/plugins/saprfc/old_perl_scripts/check_sap_rfc.py`
4. You need a configuration file (e.g., /neteye/shared/monitoring/plugins/saprfc/old_perl_scripts/nag_sap.cfg), with the following structure (substitute the values in `<>` with the actual values
```
#<SID> <SYSNR> <MANDANT> <SAP-USER> <PASSWORD> [<ASHOST>] [<SAP-ROUTER-STRING>]
<SID-1> <SYSNR-1> <MANDANT-1> <SAP-USER-1> <PASSWORD-1> [<ASHOST>] [<SAP-ROUTER-STRING>]
<SID-2> <SYSNR-2> <MANDANT-2> <SAP-USER-2> <PASSWORD-2> [<ASHOST>] [<SAP-ROUTER-STRING>]
...
```





