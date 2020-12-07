# Powershell call for remote Icinga2 Agent setup

Here you will find 2 approaches for automated setup and configuration of Icinga2 Agent.

- neteye_simple_agent_deployment
- neteye_agent_deployment

For both approaches make sure to provide the setup of the Icinga2 Agent via HTTPS link or file-share.

Next fetch the powershell script and execute the script: 
```
https://neteye.mydomain.lan/neteyeshare/monitoring/agents/microsoft/icinga/neteye_agent_deployment.ps1

> Invoke-Command -ComputerName COMPUTERNAME -FilePath C:\<filestorage>\neteye_agent_deployment.ps1 -Credential domain\user
```

## !! Advice !! - Agent setup in remote satellite zone without access to Director self-service API requires various configurations to be provided from your site:

To setup do:
- Provide the Icinga2 .msi via https or file-share
- publish the Icinga2 API to generate a host's ticket
- configure Icinga2 CA Proxy
- test the various services

In general: this approach requires configurations on the Icinga2 / NetEye 4 infrastructure not documented in this section. In case you need help please contact our staff assisting you in your daily NetEye 4 tasks.
