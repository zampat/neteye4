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

  psexec64 SC CONFIG "%ICINGASRV%" obj="%ICINGASRV_Logon%"

  echo "Restarting Icinga service ...."
  psexec64 \\%%h sc stop %ICINGASRV%
	
  echo "Starting service..."
  psexec64 \\%%h sc start %ICINGASRV%
  
  echo "Done for Host: %%h"
)

:End
echo "Abort of script"
