@echo off
:: Script to reconfigure a previously configured Icinga2 Agent service
:: Define the list of remote hosts in for loop seciont

:: NO configuration beyond this line 
SET ICINGASRV=icinga2
SET ICINGASRV_Logon=LocalSystem

for %%h in (
localhost
host1
host2
host3
) do (
	   
  if %%h.==. echo Run this command with remote hostname
  if %%h.==. goto :EOF

  echo ">>> Starting Icinga2 Agent reconfiguration for Host: %%h"
  echo ">>> Starting Icinga2 Agent reconfiguration for Host: %%h">>c:\temp\reconfigure_Icinga2Agent_LogonName.log

  echo "psexec64 \\%%h SC CONFIG %ICINGASRV% obj= %ICINGASRV_Logon%">>c:\temp\reconfigure_Icinga2Agent_LogonName.log
  psexec64 \\%%h SC CONFIG "%ICINGASRV%" obj= "%ICINGASRV_Logon%">>c:\temp\reconfigure_Icinga2Agent_LogonName.log

  echo "Restarting Icinga service ....">>c:\temp\reconfigure_Icinga2Agent_LogonName.log
  psexec64 \\%%h sc stop %ICINGASRV%>NUL
	
  echo "Starting service...">>c:\temp\reconfigure_Icinga2Agent_LogonName.log
  psexec64 \\%%h sc start %ICINGASRV%>NUL
  
  echo "Done for Host: %%h"
  echo "Done for Host: %%h">>c:\temp\reconfigure_Icinga2Agent_LogonName.log
)

:End
echo "Abort of script"
