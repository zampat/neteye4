@echo on
:: Define the Powershell script(s)  to copy to remote host1
:: Define the list of remote hosts to install and configure agent

SET AgentInstallPS=install_icinga2_agent.ps1
SET AgentInstallPSM="Icinga2Agent.psm1"

for %%h in (
host1
host2
host3
) do (
	   
if %%h.==. echo Run this command with remote hostname
if %%h.==. goto :EOF

echo ">>> Starting Agent setup and configuration for Host: %%h"

echo " - Copy %AgentInstallPS% and %AgentInstallPSM% to \\%%h\c$\temp"
md \\%%h\c$\temp

copy %AgentInstallPS% \\%%h\c$\temp\
if errorlevel 1 goto End

echo " - Start Agent setup and configuration"
echo "psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe Set-ExecutionPolicy Bypass"
psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe Set-ExecutionPolicy Bypass
echo "psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe c:\temp\%AgentInstallPS%"
psexec64 \\%%h C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe c:\temp\%AgentInstallPS%
echo "Done for Host: %%h"
)

:End
echo "Abort of script"
