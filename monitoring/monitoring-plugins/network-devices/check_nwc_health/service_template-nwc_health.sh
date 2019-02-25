#
#Service template check_nwc_health


#Requirements check
RES=`icingacli director service exists "generic_snmp"`
if [[ $RES =~ "does not exist" ]]
then
   echo "[-] Requirements check failure: Required service tempate 'generic_snmp' does not exists"
   exit 1
fi


# HowTo Export:
# icingacli director service show generic_nwc_health_snmp_v2 --json --no-defaults

RES=`icingacli director service exists "generic_nwc_health_snmp_v2"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'generic_nwc_health_snmp_v2' does not exists"

icingacli director service create generic_nwc_health_snmp_v2 --json '
{
    "check_command": "nwc_health",
    "imports": [
        "generic_snmp"
    ],
    "object_name": "generic_nwc_health_snmp_v2",
    "object_type": "template",
    "vars": {
        "nwc_health_community": "public"
    }
}
'
fi

RES=`icingacli director service exists "generic_nwc_health_snmp_v3"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'generic_nwc_health_snmp_v3' does not exists"

icingacli director service create generic_nwc_health_snmp_v3 --json '
{
    "check_command": "nwc_health",
    "imports": [
        "generic_snmp"
    ],
    "object_name": "generic_nwc_health_snmp_v3",
    "object_type": "template"
}
'
fi


RES=`icingacli director service exists "SNMP interface usage"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'SNMP interface usage' does not exists"

icingacli director service create "SNMP interface usage" --json '
{
    "check_command": "nwc_health",
    "imports": [
        "generic_nwc_health_snmp_v2"
    ],
    "object_name": "SNMP interface usage",
    "object_type": "template",
    "vars": {
        "nwc_health_community": "public",
        "nwc_health_mode": "interface-usage"
    }
}
'
fi


RES=`icingacli director service exists "SNMP device health"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'SNMP device health' does not exists"

icingacli director service create "SNMP device health" --json '
{
    "check_command": "nwc_health",
    "imports": [
        "generic_nwc_health_snmp_v2"
    ],
    "object_name": "SNMP device health",
    "object_type": "template",
    "vars": {
        "nwc_health_community": "public",
        "nwc_health_mode": "hardware-health"
    }
}
'
fi


####################################
# Assign Fields via Mysql Query
####################################
echo 'INSERT IGNORE icinga_service_field (service_id, datafield_id, is_required) VALUES ((select id from icinga_service where object_name = "generic_nwc_health_snmp_v2"),(select id from director_datafield where varname = "nwc_health_community"),"y");' | /usr/bin/mysql director
echo 'INSERT IGNORE icinga_service_field (service_id, datafield_id, is_required) VALUES ((select id from icinga_service where object_name = "generic_nwc_health_snmp_v2"),(select id from director_datafield where varname = "nwc_health_mode"),"y");' | /usr/bin/mysql director

echo 'INSERT IGNORE icinga_service_field (service_id, datafield_id, is_required) VALUES ((select id from icinga_service where object_name = "generic_nwc_health_snmp_v3"),(select id from director_datafield where varname = "nwc_health_community"),"y");' | /usr/bin/mysql director
echo 'INSERT IGNORE icinga_service_field (service_id, datafield_id, is_required) VALUES ((select id from icinga_service where object_name = "generic_nwc_health_snmp_v3"),(select id from director_datafield where varname = "nwc_health_mode"),"y");' | /usr/bin/mysql director
