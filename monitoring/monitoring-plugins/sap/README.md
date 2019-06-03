# SAP Monitorig via RFCGuide

## Introduction

SAP provides the possibility to run commands/abap scripts via RFC. In this section I will introduce an open-source framework to setup a monitorin via SAP NetWeaver RFC calls.
 
## Setup of SAP envirionment

The monitoring will be based on Python3 using the following framework:
https://sap.github.io/PyRFC/index.html

Instrucitons for setup:
- Get SAP NWRFCSDK from SAP portal using you customer's account: Downlod archive for environment "linux x86_64"
- [Unzip and install the nwrfcsdk in /usr/local/sap/](https://sap.github.io/PyRFC/install.html#sap-nw-rfc-sdk-installation)
- Publish the nwrfcsdk sap libs using ld:
```
[root@neteyedewzr ~]# cat /etc/ld.so.conf.d/nwrfcsdk.conf
# include nwrfcsdk
/usr/local/sap/nwrfcsdk/lib
```

## Setup of Python 3.6 envirionment

Requirement: install epel repo
```
yum --enablerepo=epel install python36-pip.noarch python36-virtualenv.noarch
```

Setup a python3 virtualenv:
```
cd /opt/neteye/
virtualenv saprfc

source saprfc/bin/activate
(saprfc) [root@neteyedewzr neteye]#
(saprfc) [root@neteyedewzr neteye]# pip freeze
(saprfc) [root@neteyedewzr neteye]# pip install
```

