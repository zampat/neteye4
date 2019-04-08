[<<< Back to documentation overview <<<](./README.md)

# Neteye Configurations and Template Library Setup

Open source library of monitoring templates for Icinga2. Those templates work in addtion to the Icinga2 Template Library (ITL) and can be [installed from repository](https://github.com/zampat/icinga2-monitoring-templates)

With the provided steps contens of the present repository and the monitoring templates libary are installed.

## Installation and setup

- Clone the present repository to a local drive on neteye
- Start the deployment of provided scripts and fetch ressources from third-party repositories by running the run_setup.sh.
  For Details on [actions performed by run_setup.sh see documentation](../scripts/)
```
mkdir /tmp/ns/
cd /tmp/ns
git clone https://github.com/zampat/neteye4
cd neteye4
./run_setup.sh

systemctl restart httpd.service
```
- Import all neteye monitoring templates in Icinga2 Director DB installed within the neteyeshare   
```
cd /neteye/shared/neteyeshare/monitoring/monitoring-templates
./run_import.sh
```

## Updates from community repo

Principally all improvements provided by this repository support an incremental update of you configuration. __Existing configurations are not altered.__
To update and install latest neteye4 configurations, agents and update share at any later moment:
```
cd neteye4
git fetch
git pull
./run_setup.sh
```
To update the neteye4 monitoring template library at any later moment and inject templates to Director:
```
cd /neteye/shared/neteyeshare/monitoring/monitoring-templates
git fetch
git pull
./run_import.sh
```
