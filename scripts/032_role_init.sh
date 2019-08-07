#!/bin/bash

#Define Variables
# ARG1: ICINGA2_CONF_HOME_DIR="/neteye/shared/icingaweb2/conf"
FILE_RESSOURCES="$1/roles.ini"

# Check if additional default roles already exists
grep "monitoring_unlimited_operator" $FILE_RESSOURCES > /dev/null 2>&1
RES=$?
if [ $RES -ne 0 ]
then
   echo "[i] 032: Adding Roles to authentication management."
   cat >>$FILE_RESSOURCES <<EOM
[monitoring_unlimited_operator]
permissions = "application/share/navigation, application/log, config/*, module/analytics, module/auditlog, module/businessprocess, businessprocess/showall, businessprocess/create, businessprocess/modify, module/director, director/api, director/audit, director/showconfig, director/showsql, director/deploy, director/hosts, director/services, director/servicesets, director/service_set/apply, director/users, director/notifications, director/inspect, director/monitoring/services-ro, director/*, module/doc, module/fileshipper, module/geomap, geomap/admin, geomap/editor, geomap/viewer, module/idoreports, module/ipl, module/lampo, module/leafletjs, module/licenses, module/monitoring, monitoring/command/*, module/nagvis, nagvis/edit, nagvis/admin, nagvis/overview, module/neteye, module/pdfexport, module/reactbundle, module/reporting, module/tornado, module/vsphere, module/vspheredb"

[monitoring_unlimited_ro]
permissions = "application/share/navigation, application/log, module/analytics, module/auditlog, module/doc, module/geomap, geomap/viewer, module/idoreports, module/ipl, module/lampo, module/leafletjs, module/monitoring, module/nagvis, nagvis/overview, module/neteye, module/pdfexport, module/reactbundle, module/reporting, module/tornado, module/vspheredb"

[windows_sys_operator]
permissions = "module/analytics, module/doc, module/monitoring, monitoring/command/schedule-check, monitoring/command/acknowledge-problem, monitoring/command/remove-acknowledgement, monitoring/command/comment/*, monitoring/command/comment/add, monitoring/command/comment/delete, monitoring/command/downtime/*, monitoring/command/downtime/schedule, monitoring/command/downtime/delete, monitoring/command/process-check-result, module/pdfexport"
monitoring/filter/objects = "(hostgroup_name=windows servers||hostgroup_name=microsoft sql servers)"

[windows_sys_administrator]
permissions = "config/*, module/analytics, module/director, director/deploy, director/hosts, module/doc, module/monitoring, monitoring/command/*, director/showconfig"
director/filter/hostgroups = "windows servers"
monitoring/filter/objects = "(hostgroup_name=windows servers||hostgroup_name=microsoft sql servers)"
EOM

else
   echo "[ ] 032: Default authentication Roles already exists."
fi
