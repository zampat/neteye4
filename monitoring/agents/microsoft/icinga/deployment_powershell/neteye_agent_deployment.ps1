# Deployment script for monitoring agent deploy for NetEye 3 to NetEye 4 migration projects
#
# This script is specailized to deploy the Icinga2 Agent for operation with NetEye 4 while
# installing and maintaining a running instance of NSClient++ for NetEye 3.
#
# (C) 2019 Patrick Zambelli, Würth Phoenix GmbH
#

param(
   [string]$workpath="C:\temp-neteye",
   [string]$neteye4host="neteye.mydomain.lan",
   [string]$username = "configro",
   [string]$password = "asdfgsdfsdfec7LxB"
)


[string]$nsclient_installPath = "C:\Program Files\NSClient++"
[string]$nsclient_serviceName = "nscp"

[string]$log_file = "${workpath}\neteye_agent_deployment.log"


#[string]$url_extraplugins="https://${neteye4host}/neteyeshare/monitoring/agents/microsoft/extra_plugins/"
[string]$url_icinga2agent_path = "https://${neteye4host}/neteyeshare/monitoring/agents/microsoft/icinga"
[string]$url_icinga2agent_psm = "${url_icinga2agent_path}/Icinga2Agent.psm1"
[string]$url_icinga2agent_nsclient_ini = "${url_icinga2agent_path}/configs/nsclient.ini"
[string]$url_neteye4director = "https://${neteye4host}/neteye/director/"
[string]$date_execution = Get-Date -Format "yyyMMd"


#Creation of workdir 
if (-Not (Test-Path $workpath)) {
    New-Item -ItemType Directory -Force -Path $workpath
}


#Start execution
Set-StrictMode -Version Latest
Get-Date | Out-File -FilePath "$log_file" -Append

##############################################################################################################
# Collect the various files and folders from neteye web share

## Trust invalid ssl certificate
#add-type @"
#    using System.Net;
#    using System.Security.Cryptography.X509Certificates;
#    public class TrustAllCertsPolicy : ICertificatePolicy {
#        public bool CheckValidationResult(
#            ServicePoint srvPoint, X509Certificate certificate,
#            WebRequest request, int certificateProblem) {
#            return true;
#        }
#    }
#"@
#[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


# Web-get the Icinga2Agent.psm1 from neteye4 share
echo "Download of Icinga2Agent.psm1 from $url_icinga2agent_psm." | Out-File -FilePath "$log_file" -Append
Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $workpath"\Icinga2Agent.psm1"

# Web-get the nsclient.ini
echo "Download of nsclient.ini from $url_icinga2agent_nsclient_ini using credentials" | Out-File -FilePath "$log_file" -Append

# assemble credentials as indicated 
# https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
$authentication_pair = "${username}:${password}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
$base64 = [System.Convert]::ToBase64String($bytes)

$basicAuthValue = "Basic $base64"
$headers = @{ Authorization = $basicAuthValue }

$nsclient_dst_file = "${workpath}\nsclient.ini"
Invoke-WebRequest -Uri $url_icinga2agent_nsclient_ini -OutFile $nsclient_dst_file -Headers $headers





##############################################################################################################
# Start Icinga2 Agent setup

echo "Starting neteye_agent_deployment script...." | Out-File -FilePath "$log_file" -Append
Import-Module $workpath"\Icinga2Agent.psm1"
# Perform the setup of Icinga2 Agent via PowerShell module
echo "Invoking Icinga2Agent setup with parameters: -DirectorUrl $url_neteye4director -DirectorAuthToken '5ec20eef540332af816fb69afe10fce12fa02d80' -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -RunInstaller" | Out-File -FilePath "$log_file" -Append
Icinga2AgentModule -DirectorUrl $url_neteye4director -DirectorAuthToken 'd98e1b8a5cfe8372fdff9f28e3a90d8cb5cad754' -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -IgnoreSSLErrors -RunInstaller 



##############################################################################################################
# Customize the nsclient++ installation
#

# If download was successful replace existing .ini file
if (Test-Path $nsclient_dst_file) {

    echo "Download of nsclient.ini successful. " | Out-File -FilePath "$log_file" -Append

    # IF Nsclient is already installed AND nsclient.ini already in use we DO NOT substitute to current productive .ini file.
    if (Test-Path ${nsclient_installPath}) {

        Move-Item -Force -Path "${nsclient_dst_file}" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_new
    }

    # Alternative Logic: Replace current installed nsclient.ini
    #if (Test-Path ${nsclient_installPath}\nsclient.ini) {
    #    Copy-Item "${nsclient_installPath}\nsclient.ini" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_bak    
    #    echo "Created copy of original nsclient.ini to ${nsclient_installPath}\nsclient.ini.${date_execution}_bak." | Out-File -FilePath "$log_file" -Append
    #
    #    Move-Item -Force -Path $nsclient_dst_file -Destination ${nsclient_installPath}\nsclient.ini
    #    echo "Moved new nsclient.ini to ${nsclient_installPath}\nsclient.ini." | Out-File -FilePath "$log_file" -Append

    #    # Restart service of nsclient++ if currently running
    #    try {
    #        Get-Service -Name $nsclient_serviceName | Where-Object {$_.Status -eq "Running"} | Restart-Service
    #        echo "Restarted service of NSClient++" | Out-File -FilePath "$log_file" -Append
    #    } catch {
    #        echo "Failure while restarting service of NSClient++" | Out-File -FilePath "$log_file" -Append
    #    }
    #}

}Else {

    echo "Download of nsclient.ini was NOT successful. " | Out-File -FilePath "$log_file" -Append
}
