# Icinga agents remote installation

Deployment of Icinga2 Agent using the Director Self-Service API.

## Preparing the PowerShell install script

Copy the Icinga2Agent.psm1.default file to Icinga2Agent.ps1
Add at the bottom of the section containing the token used by self-service API (Generate in host template tab "Agent":
```
exit Icinga2AgentModule `
    -DirectorUrl       'https://neteye.mydomain/neteye/director/' `
    -DirectorAuthToken '12345678900332af816fb69afe10fce12fa02d80' `
    -IgnoreSSLErrors `
    -RunInstaller
```
Download the Icinga2Agent.ps1 and execute the powershell script in administrative session:
Note: Adjust execution policy if needed
```
> Set-ExecutionPolicy Unrestricted
> Icinga2Agent.ps1
```

## Automated deployment of Icinga2 Agent

Here you find a script collection for a deployment of the Icinga2 Agent on remote Windows servers. [Here you find the documentation.](./deploy_Icinga_agents_remotely.pdf)

