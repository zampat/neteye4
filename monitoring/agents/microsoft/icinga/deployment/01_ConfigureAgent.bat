@echo on


:: Script to install Icinga2 AGENT. File will be downloaded from NetEye 4 web-share

:: Parameters: 
::%1: Agentname
::%2: AgentTicket

:: Configure this section
:: Set constants for your neteye4 environment
SET PARENTNAME="neteye4-a.mydomain"
SET PARENTNAME2="neteye4-b.mydomain"
SET PARENTZONE=cluster-satellite

SET ICINGA_AGENT_URL=https://neteye4.mydomain/neteyeshare/monitoring/agents/microsoft/icinga/
SET ICINGA_AGENT_FILE=Icinga2-v2.10.5-x86_64.msi

:: NO configuration beyond this line
SET ICINGADATADIR=C:\ProgramData\icinga2
SET ICINGABINDIR=C:\Program Files\ICINGA2\sbin

:: Sample host values
SET AGENTNAME=%ComputerName%


:: Optional: passing computer name and/or ticket via argument
::SET AGENTNAME=%1
::SET AGENTTICKET=%2


::Start of code

@FOR /F %%s IN ('powershell -command "(get-item env:'AGENTNAME').Value.ToLower()"') DO @set AGENTNAME=%%s

IF [%AGENTNAME%]==[] (
     Cls & Color 0C
     echo "Impossible to discover hostname"
     goto end
) ELSE (
     Goto getAgent
 )

:getAgent
if exist "%CD%\%ICINGA_AGENT_FILE%" (
    echo "Icinga2 Agent msi had already been downloaded. Proceeding with install..."
) else (
    echo "Icinga2 Agent msi needs to be downloaded. Downloading now..."
	call winhttpjs.bat "%ICINGA_AGENT_URL%%ICINGA_AGENT_FILE%" -method GET -saveTo %CD%\%ICINGA_AGENT_FILE%
)
goto installIcingaAgent

:installIcingaAgent
if exist "%CD%\%ICINGA_AGENT_FILE%" (
	if not exist "%ICINGABINDIR%\icinga2.exe" (
		echo "Installing Icinga2 Agent now: msiexec /i %CD%\%ICINGA_AGENT_FILE% /quiet"
		msiexec /i %CD%\%ICINGA_AGENT_FILE% /quiet
		timeout /t 30
		echo "Installing Icinga2 Agent now: msiexec /i %ICINGABINDIR%\NSCP.msi /quiet /norestart"
		msiexec /i "%ICINGABINDIR%\NSCP.msi" /quiet /norestart
		timeout /t 30
		goto getTicket
	) else (
		echo "Icinga2 Agent already installed"
		goto getTicket
	)
) else (
	echo "Icinga2 Agent msi not found"
	goto end
)

 
:getTicket

call winhttpjs.bat "https://neteye4.mydomain/neteye/director/host/ticket?name=%AGENTNAME%" -header header.txt -user director_ro -password secret -method GET -reportfile neteyeticket.txt

for /f %%i in ('FINDSTR Status neteyeticket.txt') do SET CURL_STATUS=%%i
for /f %%i in ('FINDSTR Response neteyeticket.txt') do SET CURL_RESPONSE=%%i

echo The CURL_STATUS: %CURL_STATUS%
echo The CURL_RESPONSE: %CURL_RESPONSE%

::Search for CURL status: 200
set "search=^.*200.*$"
setlocal enableDelayedExpansion
echo(!%CURL_STATUS%!|findstr /r /c:"!search!" >nul && (
  echo "Curl Status: 200. Proceeding ...."
  rem any commands can go here
) || (
  echo "Curl Status is %CURL_STATUS%. Ticket for host '%AGENTNAME%' could not be retrieved. Stop."
  goto end
) 


for /f "tokens=2 delims=:" %%a in ("%CURL_RESPONSE%") do (
  set AGENTTICKET=%%a
)

echo "Start to register host %AGENTNAME% with Ticket: %AGENTTICKET%"


if exist "%ICINGABINDIR%\icinga2.exe" (
    echo "Icinga2 Agent is installed. Going to configure agent now ...."
	goto configAgent
) else (
    echo "Icinga2 Agent is NOT installed. Please install Icinga2 Agent first. Abort."
	goto end
)

:configAgent
"%ICINGABINDIR%\icinga2.exe" pki new-cert --cn %AGENTNAME% --key %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.key --cert %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.crt
"%ICINGABINDIR%\icinga2.exe" pki save-cert --key %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.key --cert %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.crt --trustedcert %ICINGADATADIR%/var/lib/icinga2/certs/trusted-parent.crt --host %PARENTNAME%
"%ICINGABINDIR%\icinga2.exe" node setup --ticket %AGENTTICKET% --cn %AGENTNAME% --endpoint %PARENTNAME%,%PARENTNAME%,5665 --endpoint %PARENTNAME2%,%PARENTNAME2%,5665 --zone %AGENTNAME% --parent_zone %PARENTZONE% --parent_host %PARENTNAME% --trustedcert %ICINGADATADIR%/var/lib/icinga2/certs/trusted-parent.crt --accept-commands --accept-config --disable-confd

DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\trusted-parent.crt
DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\ticket
DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\*.orig

SC STOP icinga2
timeout /t 10
SC START icinga2




:end
echo "End of Icinga2 configuration script."
pause
