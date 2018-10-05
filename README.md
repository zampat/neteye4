# NetEye 4 Monitoring Fileshare setup 

This project aims to provide scripts, monitoring plugins and other useful data to setup a folder structure to simplify monitoring operations with NetEye 4.

## Features provided

- 010: Create a folder structure for Agents, Monitoring Configuration and scripts under /neteye/shared/neteyeshare/
- 020: Fetch Icinga2 Agents from packages.icinga.org and store in /neteye/shared/neteyeshare/Monitoring/Agents/
- 030: Define sample Ressource for LDAP bind.


## Install:

Clone git repository to NetEye filesystem
```
git clone https://github.com/zampat/neteye4_monitoring_share.git
```

Run configuration and setup script
```
./neteye4_monitoring_share/run_setup.sh
```
