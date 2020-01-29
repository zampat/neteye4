:: Script reconfigure a previously installed Icinga2 Agent
:: Define the list of remote hosts in for loop seciont

:: NO configuration beyond this line 
SET ICINGADATADIR=ProgramData\icinga2
SET ICINGABINDIR=Progra~1\ICINGA2\sbin
SET ICINGASRV=icinga2

for %%h in (
host1
host2
host3
) do (
	   
  if %%h.==. echo Run this command with remote hostname
  if %%h.==. goto :EOF

  echo ">>> Starting Recovery operations for Host: %%h"

  if not exist "\\%%h\c$\%ICINGABINDIR%\icinga2.exe" (
	echo "Icinga2 agent (\\%%h\c$\%ICINGABINDIR%\icinga2.exe) ist nicht installiert. Abbruch." 
	goto End
  )
  echo "Icinga Agent is installed. Verifying API configuration ...."
  if not exist "\\%%h\c$\%ICINGADATADIR%\var\lib\icinga2\api\zones\director-global" (
	echo "Icinga2 agent API ist nicht konfiguriert. API Ordner (\\%%h\c$\%ICINGADATADIR%\var\lib\icinga2\api\zones\director-global) nicht gefunden. Abbruch." 
	goto End
  )
  echo "Icinga Agent API configured. Verify service status ...."

  echo "Verify service to be stopped ...."
  psexec64 \\%%h SC queryex "%ICINGASRV%" | Find "STATE" | Find /v "RUNNING">Nul&&(
	echo "Service %ICINGASRV% ist not runnung"

	echo "Agent ist stopped. Going to delete API folder content: \\%%h\c$\%ICINGADATADIR%\var\lib\icinga2\api\zones\*.*"
	del /S /F /Q \\%%h\c$\%ICINGADATADIR%\var\lib\icinga2\api\zones\*
	rmdir /S /Q \\%%h\c$\%ICINGADATADIR%\var\lib\icinga2\api\zones\director-global
	echo "Starting service..."
	psexec64 \\%%h Net start %ICINGASRV%
  )


  echo "Done for Host: %%h"
)

:End
echo "Abort of script"
