#!/bin/bash

FOLDER_MONITORING_AGENT_LINUX="$1/agents/linux/rhel7/icinga"
ICINGA2_AGENT_VERSION=$2
SRC_GIT_AGENT_SCRIPTS_FOLDER="./monitoring/agents/microsoft/icinga"


if [ ! -f "${FOLDER_MONITORING_AGENT_LINUX}/icinga2-$ICINGA2_AGENT_VERSION-1.el7.icinga.x86_64.rpm" ]
then
   echo "[i] 022: Installing Icinga Monitoring Agent for RHEL 7"
   mkdir -p $FOLDER_MONITORING_AGENT_LINUX
   ICINGA2_CORE_FILE="icinga2-${ICINGA2_AGENT_VERSION}-1.el7.icinga.x86_64.rpm"
   ICINGA2_BIN_FILE="icinga2-bin-${ICINGA2_AGENT_VERSION}-1.el7.icinga.x86_64.rpm"
   ICINGA2_COMMON_FILE="icinga2-common-${ICINGA2_AGENT_VERSION}-1.el7.icinga.x86_64.rpm"
   ICINGA2_IDOMYSQL_FILE="icinga2-ido-mysql-${ICINGA2_AGENT_VERSION}-1.el7.icinga.x86_64.rpm"

# Loop trough all rpms
ELEMENTS=( ICINGA2_CORE_FILE ICINGA2_BIN_FILE ICINGA2_COMMON_FILE ICINGA2_IDOMYSQL_FILE )

for FILE in ${ELEMENTS[@]}
do
   # Check if Plugin already exists. If yes: backup first
   if [ ! -f ${FOLDER_MONITORING_AGENT_LINUX}/${!FILE} ]
   then
      wget http://packages.icinga.com/epel/7Client/release/x86_64/${!FILE} -O ${FOLDER_MONITORING_AGENT_LINUX}/${!FILE}
   fi
done

fi

