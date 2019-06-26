Set-StrictMode -Version Latest

Get-Date | Out-File -FilePath "$env:TMP\setup.txt" -Append

Import-Module c:\temp\Icinga2Agent.psm1
Icinga2AgentModule -DirectorUrl 'https://ne4.neteye.lab/neteye/director/' -DirectorAuthToken 'ec60146a6b509ff8c23aa1311d2e53d31e9cd413' -RunInstaller -IgnoreSSLErrors
