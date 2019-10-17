#
#Service template check_pcmeasure


#Requirements check
RES=`icingacli director service exists "generic_snmp"`
if [[ $RES =~ "does not exist" ]]
then
   echo "[-] Requirements check failure: Required service tempate 'generic_snmp' does not exists"
   exit 1
fi


# HowTo Export:
# icingacli director service show generic_pcmeasure --json --no-defaults

RES=`icingacli director service exists "generic_pcmeasure"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'generic_pcmeasure' does not exists"

icingacli director service create check_pcmeasure --json '
{
    "check_command": "check_pcmeasure",
    "imports": [
        "generic_snmp"
    ],
    "object_name": "check_pcmeasure",
    "object_type": "template"
	"vars": {
        "check_pcmeasure_sensor": "com1.",
        "check_pcmeasure_label": "label_name",
		"check_pcmeasure_warning": "warning_value",
		"check_pcmeasure_critical": "critical_value"
    }
    }
}
'
fi

