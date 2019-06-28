#!/bin/bash

# Script action:
# Copy ITOA / Analytics dashboards to neteyeshare/
#

NETEYESHARE_MONITORING=$1

#Copy files ./monitoring/analytics_dashboards/
# Verify DST Folder exists
if [ -d "${NETEYESHARE_MONITORING}" ]
then
   echo "[+] 062: Copy analytics dashboards into $NETEYESHARE_MONITORING"
   /usr/bin/rsync -av ./monitoring/analytics_dashboards ${NETEYESHARE_MONITORING}/

else
   echo "[-] 062: Abort installing analytic dashboards to ${NETEYESHARE_MONITORING}. Folder does not exist."
fi
