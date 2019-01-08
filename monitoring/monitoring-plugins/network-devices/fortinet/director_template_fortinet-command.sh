#Commands:
# icingacli director command show check_snmp_cisco_hw --json --no-defaults
#

# Check Command:check_snmp_cisco_hw
#
RES=`icingacli director command exists "check_fortinet"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Command 'check_fortinet' does not exists"
   icingacli director command create check_fortinet --json '
{
    "arguments": {
        "-A": {
            "command_id": "224",
            "required": true,
            "set_if_format": "string",
            "value": "$snmp_v3_priv_password$"
        },
        "-C": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_community$"
        },
        "-H": {
            "command_id": "224",
            "required": true,
            "set_if_format": "string",
            "value": "$address$"
        },
        "-T": {
            "command_id": "224",
            "required": true,
            "set_if_format": "string",
            "value": "$fortinet_type$"
        },
        "-U": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_v3_username$"
        },
        "-X": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_v3_priv_password$"
        },
        "-a": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_v3_auth_protocol$"
        },
        "-s": {
            "argument_format": "string",
            "command_id": "224",
            "set_if": "$fortinet_slave$",
            "set_if_format": "string"
        },
        "-v": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_protocol$"
        },
        "-x": {
            "command_id": "224",
            "set_if_format": "string",
            "value": "$snmp_v3_priv_protcol$"
        }
    },
    "command": "PluginContribDir + \/check_fortinet.pl",
    "methods_execute": "PluginCheck",
    "object_name": "check_fortinet",
    "object_type": "object",
    "timeout": "60"
}
'
fi
