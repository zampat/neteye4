#!/bin/bash

FOLDER_MONITORING_AGENT_MICROSOFT="$1/agents/linux/rhel6/icinga"
ICINGA2_AGENT_VERSION=$2
SRC_GIT_AGENT_SCRIPTS_FOLDER="./monitoring/agents/microsoft/icinga"


if [ ! -f "${FOLDER_MONITORING_AGENT_MICROSOFT}/icinga2-$ICINGA2_AGENT_VERSION-1.el6.icinga.x86_64.rpm" ]
then
   echo "[i] 021: Installing Icinga Monitoring Agent Version $ICINGA2_AGENT_VERSION for RHEL 6"
   mkdir -p $FOLDER_MONITORING_AGENT_MICROSOFT
   ICINGA2_CORE_FILE="icinga2-${ICINGA2_AGENT_VERSION}-1.el6.icinga.x86_64.rpm"
   ICINGA2_BIN_FILE="icinga2-bin-${ICINGA2_AGENT_VERSION}-1.el6.icinga.x86_64.rpm"
   ICINGA2_COMMON_FILE="icinga2-common-${ICINGA2_AGENT_VERSION}-1.el6.icinga.x86_64.rpm"
   ICINGA2_IDOMYSQL_FILE="icinga2-ido-mysql-${ICINGA2_AGENT_VERSION}-1.el6.icinga.x86_64.rpm"
   ICINGA2_BOOST_LICENSE="boost-license1_53_0-1.53.0-0.x86_64.rpm"
   ICINGA2_LIBBOOST_PROGRAM="libboost_program_options1_53_0-1.53.0-0.x86_64.rpm"
   ICINGA2_LIBBOOST_REGEX="libboost_regex1_53_0-1.53.0-0.x86_64.rpm"
   ICINGA2_LIBBOOST_SYSTEM="libboost_system1_53_0-1.53.0-0.x86_64.rpm"
   ICINGA2_LIBBOOST_THREAD="libboost_thread1_53_0-1.53.0-0.x86_64.rpm"
   #ICINGA2_LIBBOOST_=""

# Loop trough all rpms
ELEMENTS=( ICINGA2_CORE_FILE ICINGA2_BIN_FILE ICINGA2_COMMON_FILE ICINGA2_IDOMYSQL_FILE ICINGA2_LIBBOOST_THREAD ICINGA2_BOOST_LICENSE ICINGA2_LIBBOOST_PROGRAM ICINGA2_LIBBOOST_REGEX ICINGA2_LIBBOOST_SYSTEM )

for FILE in ${ELEMENTS[@]}
do
   # Check if Plugin already exists. If yes: backup first
   if [ ! -f ${FOLDER_MONITORING_AGENT_MICROSOFT}/${!FILE} ]
   then
      wget http://packages.icinga.com/epel/6Client/release/x86_64/${!FILE} -O ${FOLDER_MONITORING_AGENT_MICROSOFT}/${!FILE}
   fi
done

fi

