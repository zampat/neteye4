# Neteye Configurations and Template Library

Open source library of monitoring templates for Icinga2. Those templates work in addtion to the Icinga2 Template Library (ITL) and can be [installed from repository](https://github.com/zampat/icinga2-monitoring-templates)

With the provided steps contens of the present repository and the monitoring templates libary are installed.

## Installation and setup

- Clone the present repository to a local drive on neteye and run the setup script.
   For Details what this [setup is performing see scripts section](../scripts/)
```
mkdir /tmp/ns/
cd /tmp/ns
git clone https://github.com/zampat/neteye4
cd neteye4
./run_setup.sh
```
- Import all neteye monitoring templates in Icinga2 Director DB installed within the neteyeshare   
```
cd /neteye/shared/neteyeshare/monitoring/monitoring-templates
./run_import.sh
systemctl restart httpd.service
```

## Updates from community repo

Principally all changes are provided to allow an incremental update. Existing configurations must not be changed at any time.
To update the template library at any later moment to fetch latest improvements:
```
cd /neteye/shared/neteyeshare/monitoring/monitoring-templates
git fetch
git pull
```
