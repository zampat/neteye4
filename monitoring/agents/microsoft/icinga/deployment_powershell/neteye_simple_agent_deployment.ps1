# Security policies might enforce TLS 1.2 in order to allow Invoke-Webrequest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

[string]$icinga2ver="2.11.3"
[string]$username = "api-agent"
[string]$password = "generation"
[string]$parent_zone = "dmz-demo"
[string]$sat_server = "pbzsat-demo"

[string]$workpath="C:\temp"
[string]$icinga2="C:\Program Files\ICINGA2\sbin\icinga2.exe"
[string]$icinga2data="C:\ProgramData\icinga2"
[string]$CertificatesPath = "C:\ProgramData\icinga2\var\lib\icinga2\certs"
[string]$myFQDN=((Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain).ToLower()


# 1 step: Icinga2 install msi
$r = Get-WmiObject Win32_Product | Where {($_.Name -match 'Icinga 2')}
if (($r -ne $null) -and (-not ($r.Version -match $icinga2ver))) {
	Write-Host "Icinga must be uninstalled"
	$MSIArguments = @(
	    "/x"
	    $r.IdentifyingNumber
	    "/qn"
	    "/norestart"
	)
	Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
	$r = $null
	Remove-Item $icinga2data -Force  -Recurse -ErrorAction SilentlyContinue
}
if ($r -eq $null) {
	Write-Host "Icinga must be installed"
    Write-Host "Running command: /i " + (Get-Location).Path + "\Icinga2-v${icinga2ver}-x86_64.msi /qn /norestart"
	$MSIArguments = @(
	    "/i"
	    (Get-Location).Path + "\Icinga2-v${icinga2ver}-x86_64.msi"
	    "/qn"
	    "/norestart"
	)
	Remove-Item $icinga2data -Force  -Recurse -ErrorAction SilentlyContinue
	Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
}


# 2 step: generate ticket from satellite
$parms = '-k', '-s', '-u', "${username}:${password}", '-H', '"Accept: application/json"', '-X', 'POST', "`"https://${sat_server}:5665/v1/actions/generate-ticket`"", '-d', "`"{ `\`"cn`\`":`\`"${myFQDN}`\`" }`""
$cmdOutput = &".\curl.exe" @parms | ConvertFrom-Json

if (-not ($cmdOutput.results.code -eq "200.0")) {
    Write-Host "Cannot generate ticket. Abort now!"
    exit
}

Write-Host "Generated ticket: " $cmdOutput.results.ticket

$ticket = $cmdOutput.results.ticket


# 3 step: generate local certificates
$parms = 'pki', 'new-cert', '--cn', "${myFQDN}", '--key', "${CertificatesPath}\${myFQDN}.key", '--cert', "${CertificatesPath}\${myFQDN}.crt"
$cmdOutput = &$icinga2 @parms

Write-Host $cmdOutput

if (-not ($cmdOutput -match "Writing X509 certificate")) {
    Write-Host "Cannot generate certificate. Abort now!"
    exit
}


# 4 step: get trusted certificates
$parms = 'pki', 'save-cert', '--host', "${sat_server}", '--port', '5665', '--trustedcert', "${CertificatesPath}\trusted-parent.crt"
$cmdOutput = &$icinga2 @parms

Write-Host $cmdOutput

if (-not ($cmdOutput -match "Retrieving X.509 certificate")) {
    Write-Host "Cannot retrieve parent certificate. Abort now!"
    exit
}


# 5 step: node setup
$parms = 'node', 'setup', '--parent_host', "${sat_server},5665", '--listen', '::,5665', '--cn', "${myFQDN}", '--zone', "${myFQDN}", '--parent_zone', """${parent_zone}""", '--trustedcert', "${CertificatesPath}\trusted-parent.crt", '--endpoint', "${sat_server},${sat_server}", '--ticket', "${ticket}", '--accept-config', '--accept-commands', '--disable-confd'
Write-Host "Starting node setup with parms: " $parms
$cmdOutput = &$icinga2 @parms

Write-Host $cmdOutput

if ($cmdOutput -match "Make sure to restart Icinga 2") {
    Restart-Service -Name icinga2
    Start-Sleep -s 15
    Restart-Service -Name icinga2
    Write-Host "Icinga2 service restarted twice"
}
