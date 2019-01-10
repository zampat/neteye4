#!/bin/bash

# Script action:
# Copy all Monitoring Plugins from GIT folder "monitoring-plugins" to local neteyeshare folder.
#

# PluginsContribDir: i.e. /neteye/shared/neteyeshare/monitoring
NETEYESHARE_MONITORING=$1

#Copy files ./monitoring/monitoring-plugins
if [ ! -d ${NETEYESHARE_MONITORING}/monitoring-plugins/ ]
then
   echo "[ ] Copy content of configurations"
   cp -r ./monitoring/monitoring-plugins $NETEYESHARE_MONITORING
fi
