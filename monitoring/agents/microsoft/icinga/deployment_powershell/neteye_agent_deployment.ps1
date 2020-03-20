# Deployment script for monitoring agent deploy for NetEye 3 to NetEye 4 migration projects
#
# This script is specailized to deploy the Icinga2 Agent for operation with NetEye 4 while
# installing and maintaining a running instance of NSClient++ for NetEye 3.
#
# Changelog:
# 1.1 2020-03-20: 
# - Add switch variables to define the actions to perform
# - Ability to distribute additional monitoring plugins
# - Ability to customize nsclient.ini
# 
# (C) 2019 - 2020 Patrick Zambelli, Würth Phoenix GmbH
#

param(
   [string]$workpath="C:\temp",
   [string]$neteye4host="neteye4n1",
   [string]$username = "configro",
   [string]$password = "PWTg4vKCB622C",
   [string]$director_token = "4cab4937c05415d20b388c036f0ac5ef678ef872"
)

##### Settings regarding connection to NetEye hosts #####
[bool]$avoid_https_requests = $TRUE 

##### Actions to perform ####

# Required in case of invalid HTTPS Server certificate. Then all required files need to be provided in work directory.
[bool]$action_uninstall_Icinga2_agent = $FALSE
[bool]$action_install_Icinga2_agent = $TRUE


[bool]$action_install_OCS_agent = $FALSE



##### Other customizings and settings ####
# If variable is set the corresponding action is started.

# The icinga2 service users is overriden.
[string]$icinga2agent_service_name = "LocalSystem"

# Download extra Plugins if String is filled with values
[string]$url_mon_extra_plugins = "$url_icinga2agent_path/monitoring_plugins/monitoring_plugins.zip"

# Fetch custom nsclient.ini
[string]$url_icinga2agent_nsclient_ini = "${url_icinga2agent_path}/configs/nsclient.ini"

##### Other variables #####
[string]$nsclient_installPath = ""
[string]$nsclient_serviceName = "nscp"
[string]$icinga_installPath = "C:\Program Files\ICINGA2"
[string]$icinga_serviceName = "icinga2"

[string]$log_file = "${workpath}\neteye_agent_deployment.log"

[string]$url_icinga2agent_path = "https://${neteye4host}/neteyeshare/monitoring/agents/microsoft/icinga"
[string]$url_icinga2agent_psm = "${url_icinga2agent_path}/deployment_scripts/Icinga2Agent.psm1"

[string]$url_neteye4director = "https://${neteye4host}/neteye/director/"

[string]$date_execution = Get-Date -Format "yyyMMd"

[string]$url_ocsagent_path = "$url_icinga2agent_path/asset_management/agent/OcsPackage.exe"


#Verify workdir exists
if (-Not (Test-Path $workpath)) {
    New-Item -ItemType Directory -Force -Path $workpath
}


#Start execution
Set-StrictMode -Version Latest
Get-Date | Out-File -FilePath "$log_file" -Append


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

##############################################################################################################
# Collect the various files and folders from neteye web share
echo "Starting neteye_agent_deployment script...." | Out-File -FilePath "$log_file" -Append
Write-Host "Starting neteye_agent_deployment script...."


# Section: Install Icinga2 Agent via PowerShell Module
if ( $action_install_Icinga2_agent -eq $TRUE ){

    Write-Host "Starting Section: Install Icinga2 Agent via PowerShell Module"

    # Web-get the Icinga2Agent.psm1 from neteye4 share
    $icinga2agent_psm1_file = "$workpath\Icinga2Agent.psm1"

    if (-not $avoid_https_requests){

        Write-Host "Going to download $url_icinga2agent_psm ...."
        Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $icinga2agent_psm1_file
    } else {
        Write-Host "Offline mode: Avoid to download $url_icinga2agent_psm."
    }

    if (Test-Path -Path $icinga2agent_psm1_file){
        
        Write-Host "Icinga2Agent.psm1: OK available in $icinga2agent_psm1_file"
    } else {
        Write-Host "Icinga2Agent.psm1: NOT AVAILABLE in $icinga2agent_psm1_file. Abort now!"
        exit
    }
    Import-Module $workpath"\Icinga2Agent.psm1"

}

# Section: Install Icinga2 Agent via PowerShell Module
if ( $action_uninstall_Icinga2_agent -eq $TRUE ){
    
    # Perform uninstall
    Write-Host "Perform Uninstallation of Icinga2 Agent now..."
    echo "Perform Uninstallation of Icinga2 Agent now..." | Out-File -FilePath "$log_file" -Append
    Icinga2AgentModule -FullUninstallation -RunUninstaller
}



# Section: Install Icinga2 Agent via PowerShell Module
if ( $action_install_Icinga2_agent -eq $TRUE ){

    # Perform the setup of Icinga2 Agent via PowerShell module
    $module_call = "-DirectorUrl $url_neteye4director -DirectorAuthToken $director_token -IcingaServiceUser $icinga2agent_service_name -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -IgnoreSSLErrors -RunInstaller"
    echo "Invoking Icinga2Agent setup with parameters: $module_call" | Out-File -FilePath "$log_file" -Append
    Write-Host "Invoking Icinga2Agent setup with parameters: $module_call"

    Icinga2AgentModule -DirectorUrl $url_neteye4director -DirectorAuthToken $director_token -IcingaServiceUser $icinga2agent_service_name -NSClientEnableFirewall = $TRUE -NSClientEnableService = $TRUE -IgnoreSSLErrors -RunInstaller

    # EXperimental
    # IF defined: Override the Icinga2 Agent service user logOn
    #if ($icinga2agent_service_name.Length -gt 1){
    #
    #    echo "Reconfiguring Icinga2 Agent service login account to: $icinga2agent_service_name" | Out-File -FilePath "$log_file" -Append
    #    Write-Host "Reconfiguring Icinga2 Agent service login account to: $icinga2agent_service_name"
    #    $service = Get-WmiObject -Class Win32_Service -Filter "Name='icinga2'"
    #    $service.StopService()
    #    $service.Change($null,$null,$null,$null,$null,$null,$icinga2agent_service_name,$null,$null,$null,$null)
    #    $service.StartService()
    #}
}


# Section: Download extra plugins from neteyeshare
if ($url_mon_extra_plugins.Length -gt 1){

    $icinga2_monitoring_plugins_dst_path = "${workpath}\monitoring_plugins.zip"

    # assemble credentials as indicated 
    # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
    $authentication_pair = "${username}:${password}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $basicAuthValue = "Basic $base64"
    $headers = @{ Authorization = $basicAuthValue }

    # CHECK IF Icinga Agent is installed
    if (Get-Service -Name $icinga_serviceName -ErrorAction SilentlyContinue){

        Write-Host "Going to download and install 'extra monitoring Plugins' ..."

        if (-Not (Test-Path "$icinga_installPath/sbin/scripts")) {
           New-Item -ItemType Directory -Force -Path "$icinga_installPath/sbin/scripts"
        }

        # Install custom monitoring plugins
        Write-Host "Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials"
        echo "Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials" | Out-File -FilePath "$log_file" -Append
        Invoke-WebRequest -Uri $url_mon_extra_plugins -OutFile $icinga2_monitoring_plugins_dst_path -Headers $headers

        # monitoring_plugins.zip entpacken
        # Auf PowerShell Version prüfen und ggf. reagieren
        $psversion = $PSVersionTable.PSVersion | select Major
        $min_psversion = New-Object -TypeName System.Version -ArgumentList "5","0","0"

        if ($psversion.Major -lt $min_psversion.Major) {    
            Write-Host "Unzip of Archive for Powershell Verson before 5.0 starting ..."
            $shell = New-Object -ComObject shell.application
            $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
            foreach ($item in $zip.items()) {
                $shell.Namespace("$icinga_installPath\sbin\scripts").copyhere($item,0x14)
            }
        } else {
            Write-Host "Unzip of Archive for Powershell Verson after 5.0 starting ..."
            Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$icinga_installPath\sbin\scripts" -Force
        }
     
    } else {
        Write-Host "Abort of download and install of 'extra monitoring Plugins: Icinga2 Service is NOT installed"
    }
}



# Test if nsclient++ is installed
if (Test-Path "C:\Program Files\NSClient++") {
    $nsclient_installPath = "C:\Program Files\NSClient++"
}
elseif (Test-Path "C:\Program Files\NetEyeNSClient++") {
    $nsclient_installPath = "C:\Program Files\NetEyeNSClient++"
}


# Section: Customize the nsclient++ installation
if ($url_icinga2agent_nsclient_ini.Length -gt 1){

    Write-host "Start nsclient++ customizing"

    # Erst prüfen, ob NSClient erkannt wurde
    If ($nsclient_installPath -eq $null) {

        echo "  -ERROR: Installation-Path of NSClient not found!" | Out-File -FilePath "$log_file" -Append
        Write-Output "ERROR: Installation-Path of NSClient not found!"

    } else {

        # Web-get the nsclient.ini
        Write-Host "Going to download of nsclient.ini from $url_icinga2agent_nsclient_ini using credentials"

        $nsclient_dst_file = "${workpath}\nsclient.ini"
        Invoke-WebRequest -Uri $url_icinga2agent_nsclient_ini -OutFile $nsclient_dst_file -Headers $headers

        # If download was successful replace existing .ini file
        if (Test-Path $nsclient_dst_file) {

            Write-Host "  -Download of nsclient.ini successful. "

            Copy-Item "${nsclient_installPath}\nsclient.ini" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_bak    
            Write-Host "  -Created copy of original nsclient.ini to ${nsclient_installPath}\nsclient.ini.${date_execution}_bak."
    
            Move-Item -Force -Path $nsclient_dst_file -Destination ${nsclient_installPath}\nsclient.ini
            Write-Host "  -Moved new nsclient.ini to ${nsclient_installPath}\nsclient.ini."

            # Restart service of nsclient++ if currently running
            if (Get-Service -Name $nsclient_serviceName -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"} | Restart-Service){
                Write-Host "  -Restarted service of NSClient++"
            } else {
                Write-Host "  -Failure while restarting service of NSClient++"
            }
        }
    }
}


#
# Section: Expand NSClient Plugins to NSClient\scripts
If ($nsclient_installPath -ne $null) {

    Write-Host "  -Expand Monitoring Plugins to NSClient++ install path"

    if ($psversion.Major -lt $min_psversion.Major) {
        
        Write-Host "  -Powershell is below 5.0"
        $shell = New-Object -ComObject shell.application
        $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
        foreach ($item in $zip.items()) {
            $shell.Namespace("$nsclient_installPath\scripts").copyhere($item,0x14)
        }
    } else {
        Write-Host "  -Powershell is above 5.0 and Expand-Archive is supported"
        Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$nsclient_installPath\scripts" -Force
    }
}else {
    Write-Host "Error: NSClient++ Service is NOT installed"
    Write-Host "  -ERROR: NSClient++ Service is NOT installed"
}



#
# Section: Deployment of OCSAgent
if ( $action_install_OCS_agent -eq $TRUE ){

    Write-Host "Going to deploy OCS agent ..."

    $ocsagent_dst_file = "${workpath}\OcsPackage.exe"
    If (Get-Service -Name "OCS Inventory Service" -ErrorAction SilentlyContinue) {
        Write-Host "OCS Agent is already installed - nothing todo"
    
    } else {

        # Download OCSPackage
        Write-Host "OCS has to be installed. Downloading OCSPackage from $url_ocsagent_path"

        Invoke-WebRequest -Uri $url_ocsagent_path -OutFile $ocsagent_dst_file -Headers $headers

        # If download was successful start installation
        If (Test-Path $ocsagent_dst_file) {

           Write-Host "Start OCS-Agent Installation"
           echo "  -START OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append

           Start-Process -Wait -FilePath $ocsagent_dst_file 
           Write-Host "END OCS-Agent Installation"
           echo "  -END OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append
        }

    }
}


# temp directory clean up
Write-Host "Terminating: clean of temp-directory"
echo "clean temp-directory" | Out-File -FilePath "$log_file" -Append

If (Test-Path $ocsagent_dst_file) {
    Write-Host "Removing: $ocsagent_dst_file"
    Remove-Item $ocsagent_dst_file -Force
}

If (Test-Path $icinga2_monitoring_plugins_dst_path) {
    Write-Host "Removing: $icinga2_monitoring_plugins_dst_path"
    Remove-Item $icinga2_monitoring_plugins_dst_path -Force
}

If (Test-Path $icinga2agent_psm1_file) {
    Write-Host "Removing: $icinga2agent_psm1_file"
    Remove-Item $icinga2agent_psm1_file -Force
}

If (Test-Path "$workpath/Icinga2-*.msi") {
    Write-Host "Removing: $workpath/Icinga2-*.msi"
    Remove-Item "$workpath/Icinga2-*.msi"
}

Write-Host "Procedure completed. Done. ;o)"
