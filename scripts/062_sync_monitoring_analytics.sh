#!/bin/bash

# Script action:
# Copy ITOA / Analytics dashboards to neteyeshare/
#

NETEYESHARE_MONITORING=$1

#Copy files ./monitoring/analytics_dashboards/
if [ ! -d ${NETEYESHARE_MONITORING}/analytics_dashboards/ ]
then
   echo "[+] 062: Copy analytics dashboards into $NETEYESHARE_MONITORING"
   cp -r ./monitoring/analytics_dashboards $NETEYESHARE_MONITORING
fi
