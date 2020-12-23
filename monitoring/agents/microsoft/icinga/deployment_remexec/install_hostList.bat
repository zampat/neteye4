@echo off
:: Define the Powershell script(s)  to copy to remote host1
:: Define the list of remote hosts to install and configure agent

SET url_AgentInstall_path=https://neteye4.mydomain/neteyeshare/monitoring/agents/microsoft/icinga/wp_pbzneteye4_monitoring/install_master_icinga2Agent.ps1
SET url_AgentInstall_file=install_master_icinga2Agent.ps1
SET path_workdir=c:\temp2

for %%h in (
-host1
-host2
-host3
) do (
	   
if %%h.==. echo Run this command with remote hostname
if %%h.==. goto :EOF

echo ">>> Starting Agent setup and configuration for Host: %%h"



echo psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe Invoke-WebRequest -Uri %url_AgentInstall_path% -OutFile %path_workdir%\%url_AgentInstall_file%
psexec64 -s \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe Invoke-WebRequest -Uri %url_AgentInstall_path% -OutFile %path_workdir%\%url_AgentInstall_file%

echo "[i] Proceeding with Icinga2Agent setup and configuration"
echo psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe %path_workdir%\%url_AgentInstall_file%
psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe %path_workdir%\%url_AgentInstall_file%

echo "[+] Done for Host: %%h"
)

:End
echo "Abort of script"
