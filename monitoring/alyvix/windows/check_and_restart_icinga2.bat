@echo off
dir c:\ProgramData\icinga2\var\log\icinga2\icinga2.log
"c:\Program Files\NSClient++\nscp.exe" client --module CheckDisk --show-all -a path=c:\ProgramData\icinga2\var\log\icinga2 -a pattern=icinga2.log -a "filter=written > -5m" -a "crit=count < 1" -q check_files
if ERRORLEVEL 1 (
	schtasks /End /TN "Start Icinga2 Agent"
	schtasks /Run /TN "Start Icinga2 Agent"
)
rem pause