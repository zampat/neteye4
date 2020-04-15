# Powershell call for remote Icinga2 Agent setup

Get powershell for remote execution from Neteye4 share:
https://neteye.mydomain.lan/neteyeshare/monitoring/agents/microsoft/icinga/neteye_agent_deployment.ps1

Command:
```
> Invoke-Command -ComputerName COMPUTERNAME -FilePath C:\<filestorage>\neteye_agent_deployment.ps1 -Credential domain\user
```

## !!Experimental Advice !! - Agent setup in remote satellite zone without access to Director API

In protected subnets i.e. DMZ it could be impossible to register Agents by calling the Director API.
To setup do:
- install a proxy on the neteye satellite and 
- register the neteye `master` into the host's local "hosts" file.
In this way an agent is able to register its hosts through a neteye satellite server. **Remember: This workaround is experimental.**
Note: This approach is experimental.

You can find the sample script in folder "satellite-zone".
