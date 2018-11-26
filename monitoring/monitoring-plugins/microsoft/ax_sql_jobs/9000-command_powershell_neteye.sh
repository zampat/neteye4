#Commands:
# icingacli director command show powershell_neteye --json --no-defaults
#
#
# Check Command:Powershell
#
RES=`icingacli director command exists "powershell"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Command 'powershell_neteye' does not exists"
   icingacli director command create powershell --json '
{
    "arguments": {
        "(no key)": {
            "set_if_format": "string",
            "skip_key": true,
            "value": "\/c echo C:\\script\\neteye\\$powershell_scripts$ $powershell_args$; exit ($$lastexitcode) | powershell.exe -command -"
        }
    },
    "command": "c:\\Windows\\system32\\cmd.exe",
    "methods_execute": "PluginCheck",
    "object_name": "powershell_neteye",
    "object_type": "object"
}
'
fi

