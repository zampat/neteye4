# Powershell call for remote Icinga2 Agent setup

Get powershell for remote execution from Neteye4 share:
https://neteye.mydomain.lan/neteyeshare/monitoring/agents/microsoft/icinga/neteye_agent_deployment.ps1

Command:
> Invoke-Command -ComputerName COMPUTERNAME -FilePath C:\<filestorage>\neteye_agent_deployment.ps1 -Credential domain\user
