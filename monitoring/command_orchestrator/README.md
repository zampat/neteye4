# Command orchestrator How-To hints

## Create a command group

```
-> Group 1:
icingacli cmdorchestrator commandgroup create --name top-group 

Info:  Note Group ID from result. Needed for next nested group

-> Group 2:
icingacli cmdorchestrator commandgroup create --name sub-group --parent-command-group-id 1

Info:  Note Group ID from result. Needed for command
```

## Create of commands:

Note the filter expression: 
- according icingaweb2 notation
- filter on standard attribute: `"host=myhostname1"`
- filter on custom variable: `"_host_host_os=Windows"`

```
icingacli cmdorchestrator command create --name <Command name> \
   --command-type <Command type> \
   --monitoring-object-filter <Filter to locate target HO> \
   --command <Path to Plugin> \
   --command-parameters <Array of arguments> \
   --command-group-id <Parent Command Group ID>

icingacli cmdorchestrator command create \
		--name restart-service-windows \
		--command-type remote \
		--monitoring-object-filter '_host_host_os=Windows' \
		--command 'C:\\Progra~1\\Icinga2\\sbin\\scripts\\cmdo_restart_service.cmd' \
		--command-parameters  '["$service_name$"]'\
		--command-group-id 3


icingacli cmdorchestrator commandparameter create \
		--command-id 2 \
		--parameter '$service_name$' \
		--parameter-type string \
		--possible-values '["spooler", "dnscache", "wuauserv"]'
```


## EDIT EXISTING COMMANDGROUP

NOTE: You need to specify the parent group EVEN IF NULL !! - otherwise the resolution for existing parent groups will fail!
```
# icingacli cmdorchestrator commandgroup edit --id 1 --name Windows_edited --description Windows_added --parent_command_group_id null
{
    "message": "Object successfully updated",
    "result": "ok",
    "info": {
        "id": 1,
        "name": "Windows_edited",
        "description": "Windows_added",
        "parent_command_group_id": null
    }
}
```

## EDIT EXISTING COMMAND
```
icingacli cmdorchestrator command edit --id 1 --name restart-service-windows --command-type remote --monitoring-object-filter 'host=myhostname1' --command 'C:\\Progra~1\\Icinga2\\sbin\\scripts\\cmdo_restart_service.cmd' --command-parameters  '["$service_name$"]' --command-group-id 2
```
## EDIT EXISTING COMMANDPARAMETER
```
# icingacli cmdorchestrator commandparameter edit --id 6 --possible-values '["hello world", "hello test", "hello"]'
```


## Example create powershell command:
The powershell script: `test.ps1`
```
Param(	
    [Parameter()] [String] $ParameterName
)

Write-Host " hello world $ParameterName" 
```
The command:
```
# icingacli cmdorchestrator command create --name "powershell_test_args" --command-type remote --command 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' --command-parameters '["-ExecutionPolicy", "ByPass", "C:\\\\Progra~1\\\\Icinga2\\\\sbin\\\\scripts\\\\test.ps1", "$service_name$"]' --command-group-id 1 --monitoring-object-filter "host=*win*"
```
The command parameters:
```
# icingacli cmdorchestrator commandparameter create --command-id 4 --parameter '$service_name$' --possible-values '["hello world", "hello test"]' --parameter-type string
{
    "message": "Object successfully created",
    "result": "ok",
    "info": {
        "id": 6,
        "command_id": 4,
        "parameter": "$service_name$",
        "parameter_type": "string",
        "possible_values": "[\"hello world\", \"hello test\"]"
    }
}
```
