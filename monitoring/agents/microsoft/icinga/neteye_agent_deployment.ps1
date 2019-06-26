# Deployment script for monitoring agent deploy for NetEye 3 to NetEye 4 migration projects
#
# This script is specailized to deploy the Icinga2 Agent for operation with NetEye 4 while
# installing and maintaining a running instance of NSClient++ for NetEye 3.
#
# (C) 2019 Patrick Zambelli, Würth Phoenix GmbH
#

param(
   [string]$workpath="C:\temp",
   [string]$neteye4host="neteyedewzr.wgs.wuerth.com",
   [string]$username = "configro",
   [string]$password = "tvzTn6eb3Xt7C",
   [string]$director_token = "aedd7c7c84e2eab8b084f983d5ae15d905b659ad"
)

[string]$nsclient_installPath = ""
[string]$nsclient_serviceName = "nscp"
[string]$icinga_installPath = "C:\Program Files\ICINGA2"
[string]$icinga_serviceName = "icinga2"

[string]$log_file = "${workpath}\neteye_agent_deployment.log"

[string]$url_icinga2agent_path = "https://${neteye4host}/neteyeshare/monitoring/agents/microsoft/icinga"
[string]$url_icinga2agent_psm = "${url_icinga2agent_path}/deployment_scripts/Icinga2Agent.psm1"
[string]$url_icinga2agent_nsclient_ini = "${url_icinga2agent_path}/configs/nsclient.ini"
[string]$url_neteye4director = "https://${neteye4host}/neteye/director/"
[string]$date_execution = Get-Date -Format "yyyMMd"
[string]$url_mon_extra_plugins = "$url_icinga2agent_path/monitoring_plugins/monitoring_plugins.zip"


#Verify workdir exists
if (-Not (Test-Path $workpath)) {
    New-Item -ItemType Directory -Force -Path $workpath
}


#Start execution
Set-StrictMode -Version Latest
Get-Date | Out-File -FilePath "$log_file" -Append

echo "Starting neteye_agent_deployment script...." | Out-File -FilePath "$log_file" -Append




# Web-get the Icinga2Agent.psm1 from neteye4 share
Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $workpath"\Icinga2Agent.psm1"
Import-Module $workpath"\Icinga2Agent.psm1"

# Perform the setup of Icinga2 Agent via PowerShell module
echo "Invoking Icinga2Agent setup with parameters: -DirectorUrl $url_neteye4director -DirectorAuthToken $director_token -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -RunInstaller" | Out-File -FilePath "$log_file" -Append
#Icinga2AgentModule -DirectorUrl $url_neteye4director -DirectorAuthToken $director_token -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -FetchAgentFQDN -RunInstaller


# Icinga Agent is installed
if (Get-Service -Name $icinga_serviceName -ErrorAction SilentlyContinue){

    Write-Host "Icinga2 Service is installed"

    if (-Not (Test-Path "$icinga_installPath/sbin/scripts")) {
       New-Item -ItemType Directory -Force -Path "$icinga_installPath/sbin/scripts"
    }


    # Install custom monitoring plugins
    echo "Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials" | Out-File -FilePath "$log_file" -Append

    $icinga2_monitoring_plugins_dst_path = "${workpath}\monitoring_plugins.zip"
    Invoke-WebRequest -Uri $url_mon_extra_plugins -OutFile $icinga2_monitoring_plugins_dst_path -Headers $headers

    # monitoring_plugins.zip entpacken
    $psversion = $PSVersionTable.PSVersion | select Major
    $min_psversion = New-Object -TypeName System.Version -ArgumentList "5","0","0"

    # Auf PowerShell Version prüfen und ggf. reagieren
    if ($psversion.Major -lt $min_psversion.Major) {    
        echo "Powershell is below 5.0" | Out-File -FilePath "$log_file" -Append
        $shell = New-Object -ComObject shell.application
        $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
        foreach ($item in $zip.items()) {
            $shell.Namespace("$icinga_installPath\sbin\scripts").copyhere($item,0x14)
        }
    } else {
        echo "Powershell is above 5.0 and Expand-Archive is supported" | Out-File -FilePath "$log_file" -Append
        Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$icinga_installPath\sbin\scripts" -Force
    }

} else {
    Write-Host "Error: Icinga2 Service is NOT installed"
}




#
# Customize the nsclient++ installation
#
if (Test-Path "C:\Program Files\NSClient++") {
    $nsclient_installPath = "C:\Program Files\NSClient++"
}
elseif (Test-Path "C:\Program Files\NetEyeNSClient++") {
    $nsclient_installPath = "C:\Program Files\NetEyeNSClient++"
}


 # assemble credentials as indicated 
    # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
    $authentication_pair = "${username}:${password}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $basicAuthValue = "Basic $base64"

    $headers = @{ Authorization = $basicAuthValue }

# Erst prüfen, ob NSClient erkannt wurde
If ($nsclient_installPath -eq $null) {
    echo "ERROR: Installation-Path of NSClient not find!" | Out-File -FilePath "$log_file" -Append
    Write-Output "ERROR: Installation-Path of NSClient not find!"
}
else {
    # Web-get the nsclient.ini
    echo "Download of nsclient.ini from $url_icinga2agent_nsclient_ini using credentials" | Out-File -FilePath "$log_file" -Append

    $nsclient_dst_file = "${workpath}\nsclient.ini"
    Invoke-WebRequest -Uri $url_icinga2agent_nsclient_ini -OutFile $nsclient_dst_file -Headers $headers


    # If download was successful replace existing .ini file
    if (Test-Path $nsclient_dst_file) {

        echo "Download of nsclient.ini successful. " | Out-File -FilePath "$log_file" -Append

        Copy-Item "${nsclient_installPath}\nsclient.ini" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_bak    
        echo "Created copy of original nsclient.ini to ${nsclient_installPath}\nsclient.ini.${date_execution}_bak." | Out-File -FilePath "$log_file" -Append
    
        Move-Item -Force -Path $nsclient_dst_file -Destination ${nsclient_installPath}\nsclient.ini
        echo "Moved new nsclient.ini to ${nsclient_installPath}\nsclient.ini." | Out-File -FilePath "$log_file" -Append

        # Restart service of nsclient++ if currently running
        if (Get-Service -Name $nsclient_serviceName -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"} | Restart-Service){
            echo "Restarted service of NSClient++" | Out-File -FilePath "$log_file" -Append
        } else {
            echo "Failure while restarting service of NSClient++" | Out-File -FilePath "$log_file" -Append
        }
    }
}


