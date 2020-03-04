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
                    "skip_key": true,
                    "value": "; exit ($$lastexitcode)"
                },
                "-command": {
                    "skip_key": true,
                    "value": {
                        "type": "Function",
                        "body": "var powershell_script = macro(\"$powershell_script$\");\r\nvar powershell_args = macro(\"$powershell_args$\");\r\n\r\nresult = \"try { \\\" & ' \" + powershell_script + \" ' \\\" \";\r\nif (powershell_args) {\r\n    result += powershell_args;\r\n}\r\nresult += \"} catch { echo $$_.Exception ;exit 3 }\";\r\nreturn result;"
                    },
                    "order": "-2"
                }
            },
            "command": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy ByPass",
            "disabled": false,
            "fields": [],
            "imports": [],
            "is_string": null,
            "methods_execute": "PluginCheck",
            "object_name": "powershell",
            "object_type": "object",
            "timeout": "60",
            "vars": {},
            "zone": null
        }
    },
    "ServiceTemplate": {
        "windows-powershell-generic": {
            "action_url": null,
            "apply_for": null,
            "assign_filter": null,
            "check_command": "powershell",
            "check_interval": null,
            "check_period": null,
            "check_timeout": null,
            "command_endpoint": null,
            "disabled": false,
            "display_name": null,
            "enable_active_checks": null,
            "enable_event_handler": null,
            "enable_flapping": null,
            "enable_notifications": null,
            "enable_passive_checks": null,
            "enable_perfdata": null,
            "event_command": null,
            "fields": [
                {
                    "is_required": "n",
                    "var_filter": null
                },
                {
                    "is_required": "y",
                    "var_filter": null
                }
            ],
            "flapping_threshold_high": null,
            "flapping_threshold_low": null,
            "groups": [],
            "host": null,
            "icon_image": null,
            "icon_image_alt": null,
            "imports": [
                "generic-agent"
            ],
            "max_check_attempts": null,
            "notes": null,
            "notes_url": null,
            "object_name": "windows-powershell-generic",
            "object_type": "template",
            "retry_interval": null,
            "service_set": null,
            "template_choice": null,
            "use_agent": null,
            "use_var_overrides": null,
            "vars": {},
            "volatile": null,
            "zone": null
        }
    }
'
fi

