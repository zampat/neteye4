@echo off

REM Icinga2 agent installation file for neteye zones
REM - if in satellite zone with need to add host translation to point to master node

SET HOSTSFILEPATH=C:\Windows\System32\drivers\etc\hosts
SET NETEYEMASTER=neteye.mydomain.lan

findstr /m "%NETEYEMASTER%" %HOSTSFILEPATH%
if %errorlevel%==1 (
   echo Register host translation for %NETEYEMASTER% in hosts file
   @echo 10.0.0.3    neteye.mydomain.lan >> %HOSTSFILEPATH%
)

C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe Set-ExecutionPolicy Bypass
C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe .\neteye_agent_deployment.ps1
