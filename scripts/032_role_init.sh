#!/bin/bash

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
FILE_RESSOURCES="$1/roles.ini"

# Check if additional default roles already exists
grep "viewer" $FILE_RESSOURCES > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then
   echo "[i] 032: Adding Roles to authentication management."
   cat >>$FILE_RESSOURCES <<EOM
[viewer]
permissions = "module/monitoring, monitoring/command/*, monitoring/command/schedule-check, monitoring/command/acknowledge-problem, monitoring/command/remove-acknowledgement, monitoring/command/comment/*, monitoring/command/comment/add, monitoring/command/downtime/*, monitoring/command/downtime/schedule, monitoring/command/process-check-result"
director/filter/hostgroups = "Hostgroup A, Hostgroup B"
EOM

else
   echo "[ ] 032: Default authentication Roles already exists."
fi
