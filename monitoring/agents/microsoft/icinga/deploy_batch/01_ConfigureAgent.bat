@echo on
:: Script to install Icinga2 AGENT. File will be downloaded from NetEye 4 web-share
::  
:: Instructions:
:: 1. Configure the parent endpoint(s) and the parent zone
:: 2. Define NetEye / Icinga2 Url for downloading Agent 
:: 3. Define NetEye / Icinga2 Url for retrieving the Agent Ticket
:: 4. Generate Base64 encoded credentials, for authenticatin to API
:: 5. Enjoy

:: Optional Parameters: 
::%1: Agentname

:: Configure this section
:: Set constants for your neteye4 environment
SET PARENTNAME="neteye4-a.mydomain"
SET PARENTNAME2="neteye4-b.mydomain"
SET PARENTZONE=cluster-satellite

SET ICINGA_HOST_URL=https://neteye4-cl.mydomain
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
)
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
if exist "%USERHOME%\%ICINGA_AGENT_FILE%" (
    echo "Icinga2 Agent msi had already been downloaded. Proceeding with install..."
) else (
    echo "Icinga2 Agent msi needs to be downloaded. Downloading now..."
	powershell -command "Invoke-WebRequest -Uri %ICINGA_AGENT_URL%%ICINGA_AGENT_FILE% -Method 'GET' -OutFile %USERHOME%\%ICINGA_AGENT_FILE%"
)
goto installIcingaAgent

:installIcingaAgent
if exist "%USERHOME%\%ICINGA_AGENT_FILE%" (
	if not exist "%ICINGABINDIR%\icinga2.exe" (
		echo "Installing Icinga2 Agent now: msiexec /i %USERHOME%\%ICINGA_AGENT_FILE% /quiet"
		msiexec /i %USERHOME%\%ICINGA_AGENT_FILE% /quiet
		timeout /t 30
	) else (
		echo "Icinga2 Agent already installed"
	)
	if not exist "%NSCLIENTBINDIR%\nscp.exe" (
		echo "NSClient++ is not installed. Installing now: msiexec /i %ICINGABINDIR%\NSCP.msi /quiet /norestart"
		msiexec /i "%ICINGABINDIR%\NSCP.msi" /quiet /norestart
		timeout /t 30
	) else (
		echo "NSClient++ Agent already installed"
	)
	goto getTicket
) else (
	echo "Icinga2 Agent msi not found"
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
powershell -command "Invoke-WebRequest -Uri %ICINGA_TICKETAPI_URL%?name=%AGENTNAME% -Method 'POST' -Headers @{Authorization = 'Basic ZGlyZWN0b3Jfcm86cWpaMmJYamZiNHFEVkhZU0VjSFpuWg=='; 'Accept' = 'application/json'} -OutFile %USERHOME%\ticket.txt"

set /p AGENTTICKET=< %USERHOME%\ticket.txt

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
