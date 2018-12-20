#!/bin/bash

#Define Variables
FILESHARE_MONITORING="$1"
FILESHARE_MS_FAILOVER_CL_MONIT="${FILESHARE_MONITORING}/monitoring-plugins/microsoft/failover_cluster"
FILES_MS_FAILOVER_CL_MONIT="${FILESHARE_MS_FAILOVER_CL_MONIT}/Nagios_Cluster.ps1"


GIT_MS_Cluster_monitoring="https://gist.githubusercontent.com/hpmmatuska/bc94b9e087655391b251/raw/6f634953b9399a496a2b44bdc1933c1dc099b099/Nagios_Cluster.ps1"


# Microsoft Failover cluster monitoring 
if [ ! -d "${FILESHARE_MS_FAILOVER_CL_MONIT}" ]
then
   echo "[i] Create folder: ${FILESHARE_MS_FAILOVER_CL_MONIT}"
   mkdir -p ${FILESHARE_MS_FAILOVER_CL_MONIT}
fi

if [ ! -f "${FILES_MS_FAILOVER_CL_MONIT}" ]
then

   echo "[i] Microsoft Failover cluster monitoring: Downloading Check into ${FILESHARE_MS_FAILOVER_CL_MONIT}."
   /usr/bin/wget ${GIT_MS_Cluster_monitoring} -O ${FILES_MS_FAILOVER_CL_MONIT}
fi
