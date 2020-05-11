@echo on
:: Script to install Icinga2 AGENT. File will be downloaded from NetEye 4 web-share
::  
:: Instructions:
:: 1. Configure the parent endpoint(s) and the parent zone
:: 2. Define NetEye / Icinga2 Url for downloading Agent 
:: 3. Define NetEye / Icinga2 Url for retrieving the Agent Ticket
:: 4. Generate Base64 encoded credentials, for authenticatin to API
:: 5. Verify filrewall rule to be created
:: 6. Enjoy

:: Optional Parameters: 
::%1: Agentname

:: Configure this section
:: Set constants for your neteye4 environment
SET PARENTNAME="neteye4-a.mydomain"
SET PARENTNAME2="neteye4-b.mydomain"
SET PARENTZONE=cluster-satellite

SET MASTERHOST="neteye4-master.mydomain"

SET ICINGA_HOST_URL=https://neteye.mydomain.lan
SET ICINGA_AGENT_URL=%ICINGA_HOST_URL%/neteyeshare/monitoring/agents/microsoft/icinga/
SET ICINGA_TICKETAPI_URL=%ICINGA_HOST_URL%/neteye/director/host/ticket

SET ICINGA_AGENT_FILE=Icinga2-v2.10.5-x86_64.msi


:: Sample host values
SET AGENTNAME="%ComputerName%.%USERDNSDOMAIN%"

:: NO configuration beyond this line
SET ICINGADATADIR=C:\ProgramData\icinga2
SET ICINGABINDIR=C:\Program Files\ICINGA2\sbin
SET NSCLIENTBINDIR=C:\Program Files\NSClient++

::Temp files folder
SET USERHOME=%USERPROFILE%\AppData\Local\Temp


:: Optional: passing computer name and/or ticket via argument
IF NOT [%1]==[] (
	SET AGENTNAME=%1
	REM SET AGENTTICKET=%1
)



::Start of code
echo ">>> %DATE% - %TIME% Start of script execution" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 

@FOR /F %%s IN ('powershell -command "(get-item env:'AGENTNAME').Value.ToLower()"') DO @set AGENTNAME=%%s

IF [%AGENTNAME%]==[] (
     Cls & Color 0C
     echo "Impossible to discover hostname" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
     goto end
) ELSE (
	if not exist "%ICINGABINDIR%\icinga2.exe" (
		echo "Icinga2 Agent not installed. Going to install agent..." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
		Goto getAgent
	) else (
		echo "Icinga2 Agent already installed. Going to generate Ticket and certificates..." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
		goto getTicket
	)
)

:getAgent
if exist "%USERHOME%\%ICINGA_AGENT_FILE%" (
    echo "Icinga2 Agent msi had already been downloaded. Proceeding with install..." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
) else (
    echo "Icinga2 Agent msi needs to be downloaded. Downloading now..." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	powershell -command "Invoke-WebRequest -Uri %ICINGA_AGENT_URL%%ICINGA_AGENT_FILE% -Method 'GET' -OutFile %USERHOME%\%ICINGA_AGENT_FILE%"
)
goto installIcingaAgent

:installIcingaAgent
if exist "%USERHOME%\%ICINGA_AGENT_FILE%" (
	if not exist "%ICINGABINDIR%\icinga2.exe" (
		echo "Installing Icinga2 Agent now: msiexec /i %USERHOME%\%ICINGA_AGENT_FILE% /quiet" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
		msiexec /i %USERHOME%\%ICINGA_AGENT_FILE% /quiet
		timeout /t 30
	) else (
		echo "Icinga2 Agent already installed" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	)
	if not exist "%NSCLIENTBINDIR%\nscp.exe" (
		echo "NSClient++ is not installed. Installing now: msiexec /i %ICINGABINDIR%\NSCP.msi /quiet /norestart" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
		msiexec /i "%ICINGABINDIR%\NSCP.msi" /quiet /norestart
		timeout /t 30
	) else (
		echo "NSClient++ Agent already installed" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	)
	goto getTicket
) else (
	echo "Icinga2 Agent msi not found" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	goto end
)

 
:getTicket

::#Powershell to generate authentication token
:: NetEye role settings: enable module "director" with "module access","api" and "hosts".
::$authentication_pair = "director_ro:secret"
::$bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
::$base64 = [System.Convert]::ToBase64String($bytes)
::
::$basicAuthValue = "Basic $base64"
::echo "BasicAuthValue: $basicAuthValue"
::$headers = @{ Authorization = $basicAuthValue; 'Accept' = 'application/json'}

if not exist %USERHOME% (
        mkdir %USERHOME%
)

:: Skip Ticket fetch if passed via argument
IF [%AGENTTICKET%]==[] (
	powershell -command "Invoke-WebRequest -Uri %ICINGA_TICKETAPI_URL%?name=%AGENTNAME% -Method 'POST' -Headers @{Authorization = 'Basic ZGlyZWN0b3Jfcm86c2VjcmV0'; 'Accept' = 'application/json'} -OutFile %USERHOME%\ticket.txt"

	set /p AGENTTICKET=< %USERHOME%\ticket.txt
)

echo "Start to register host %AGENTNAME% with Ticket: %AGENTTICKET%"

if exist "%ICINGABINDIR%\icinga2.exe" (
    echo "Icinga2 Agent is installed. Going to configure agent now ...." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	goto configAgent
) else (
    echo "Icinga2 Agent is NOT installed. Please install Icinga2 Agent first. Abort." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 
	goto end
)

:configAgent
"%ICINGABINDIR%\icinga2.exe" pki new-cert --cn %AGENTNAME% --key %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.key --cert %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.crt
"%ICINGABINDIR%\icinga2.exe" pki save-cert --key %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.key --cert %ICINGADATADIR%/var/lib/icinga2/certs/%AGENTNAME%.crt --trustedcert %ICINGADATADIR%/var/lib/icinga2/certs/trusted-parent.crt --host %MASTERHOST%
"%ICINGABINDIR%\icinga2.exe" node setup --ticket %AGENTTICKET% --cn %AGENTNAME% --endpoint %PARENTNAME%,%PARENTNAME%,5665 --endpoint %PARENTNAME2%,%PARENTNAME2%,5665 --zone %AGENTNAME% --parent_zone %PARENTZONE% --parent_host %MASTERHOST% --trustedcert %ICINGADATADIR%/var/lib/icinga2/certs/trusted-parent.crt --accept-commands --accept-config --disable-confd

DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\trusted-parent.crt
DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\ticket
DEL /F /Q %ICINGADATADIR%\var\lib\icinga2\certs\*.orig

echo "Going to stop service icinga2" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
SC STOP icinga2 >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
echo "Sleep for 10 seconds .... " >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
timeout /t 10
SC query icinga2 >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log

echo "Going to start service icinga2" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
SC START icinga2 >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
echo "Sleep for 10 seconds .... " >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
timeout /t 10
echo "Going to query the status of service icinga2" >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log
SC query icinga2 >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log

:configureFirewallRule
::  Register a suitable firewall rule
netsh advfirewall firewall add rule name="NetEye Icinga2 Agent" dir=in action=allow program="%ProgramFiles%\ICINGA2\sbin\icinga2.exe" enable=yes protocol=TCP localport=5665

:end
echo "End of Icinga2 configuration script." 
echo "End of Icinga2 configuration script." >> %ICINGADATADIR%/var/log/icinga2/configure_agent.log 

REM pause
