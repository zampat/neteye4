###
# Create Service Set: "AIX Health"
###
# Service Template for Service Set
RES=`icingacli director serviceset exists "AIX Health"`
if [[ $RES =~ "does not exist" ]]
then
icingacli director serviceset create --json '
{
    "assign_filter": null,
    "description": null,
    "object_name": "AIX Health",
    "object_type": "template",
    "vars": {
    }
}
'


####
# Service Objects
####
icingacli director service create --json '
{
    "imports": [
        "nrpe_disk_noSSL"
    ],
    "object_name": "AIX Disk",
    "object_type": "object",
	"service_set": "AIX Health"
}'

icingacli director service create --json '
{
    "imports": [
        "nrpe_disk_noSSL"
    ],
    "object_name": "AIX Load",
    "object_type": "object",
	"service_set": "AIX Health"
}'


echo "Done"
fi



