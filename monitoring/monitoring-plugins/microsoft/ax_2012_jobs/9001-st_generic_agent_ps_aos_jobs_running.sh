RES=`icingacli director service exists "generic_agent_ps_aos_jobs_running"`
if [[ $RES =~ "does not exist" ]]
then
   echo "Service 'generic_agent_ps_aos_jobs_running' does not exists"

icingacli director service create generic_agent_ps_aos_jobs_running --json '
{
    "check_command": "powershell_neteye",
    "imports": [
        "generic_agent_powershell"
    ],
    "object_name": "generic_agent_ps_aos_jobs_running",
    "object_type": "template",
    "vars": {
        "custom_analytics_dashboard": "d\/ax-sql-jobs-overview",
        "powershell_args": "-SQLServer HH1-AXDB01 -AXDBName ax_prod -BatchOverdue 10",
        "powershell_scripts": "check_aos_jobs.ps1"
    }
}
'
fi
