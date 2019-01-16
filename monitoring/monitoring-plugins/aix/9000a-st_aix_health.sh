# 
#Services (as template)
# HowTo Export:
# icingacli director service show Agent_WinCnt --json --no-defaults
#

# Requirements Check
RES=` icingacli director service show generic_service --json --no-defaults`
if [[ $RES =~ "does not exist" ]]
then
   echo "Prerequisite failure: Service Template 'generic_service' does not exists. Abort import."
   exit 0
fi


# Import of Service Template
RES=`icingacli director service exists "generic_nrpe_noSSL"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'generic_nrpe_noSSL' does not exists"
   icingacli director service create --json '
{
    "check_command": "nrpe",
    "imports": [
        "generic_service"
    ],
    "object_name": "generic_nrpe_noSSL",
    "object_type": "template",
    "vars": {
        "nrpe_no_ssl": "true"
    }
}
'
fi

# Import of Service Template
RES=`icingacli director service exists "nrpe_disk_noSSL"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'nrpe_disk_noSSL' does not exists"
   icingacli director service create --json '
{
    "imports": [
        "generic_nrpe_noSSL"
    ],
    "object_name": "nrpe_disk_noSSL",
    "object_type": "template",
    "vars": {
        "nrpe_arguments": [
            "-c 80 -c 90 -x \/proc"
        ],
        "nrpe_command": "check_diskspace_arg"
    }
}
'
fi

# Import of Service Template
RES=`icingacli director service exists "nrpe_load_noSSL"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'nrpe_load_noSSL' does not exists"
   icingacli director service create --json '
{
    "imports": [
        "generic_nrpe_noSSL"
    ],
    "object_name": "nrpe_load_noSSL",
    "object_type": "template",
    "vars": {
        "nrpe_command": "check_load"
    }
}
'
fi

echo "Done"
exit 0
