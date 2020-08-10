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

# Changelog
# 2020-08-10
# 1. Verify is agent is already installed. If yes, perfom only update and maintain an settings including Certificats, zones.conf and constands.conf


# 
# (C) 2019 - 2020 Patrick Zambelli and contributors, Würth Phoenix GmbH
#

param(
   [string]$workpath="C:\temp",

   # Add parent zone and ca server to run check from satellite
   [string]$neteye4endpoint = $null,
   [bool]$is_neteye4endpoint_master = $FALSE,
   # [string]$parent_zone = "Test Zone Satellite",
   # [string]$ca_server = "neteye4sat.neteyelocal",
   [string]$neteye4_director_token = "559ef5ea8263654ecae42a9bcad860ad4dad60d2",

   # Version of Icinga2 Agent
   [string]$icinga2ver="2.11.3",
   
   # The icinga2 service users is overriden.
   [string]$icinga2agent_service_name = "LocalSystem",

   # Download extra Plugins if String is filled with values
   [bool]$action_extra_plugins = $TRUE,

   # Fetch custom nsclient.ini
   [bool]$action_custom_nsclient = $TRUE,

   # Required in case of invalid HTTPS Server certificate. Then all required files need to be provided in work directory.
   [bool]$action_uninstall_Icinga2_agent = $TRUE,
   [bool]$action_install_Icinga2_agent = $TRUE,
   [bool]$action_update_Icinga2_agent = $FALSE,

   [bool]$action_install_OCS_agent = $TRUE,
   
   ##### Settings regarding connection to NetEye hosts #####
   #[bool]$avoid_https_requests = $FALSE 
   # Define how to retrieve files. Supported ources are: https, fileshare, disabled
   [string]$remote_file_repository = "fileshare",

   # NetEye 4 NetEyeShare webserver credentials
   [string]$username = "configro",
   [string]$password = "PWTg4vKCB622C"
)


# Array neteye endpoint: [string]endpoint fqdn, [int]icinga2 API tcp port, [bool]is master 
$arr_neteye_endpoints = @(
    ("neteye4master.mydomain.lan",5665, $TRUE),
    ("neteye4satellite.mydomain.lan",5665, $FALSE)
)


##### Other customizings and settings ####
# If variable is set the corresponding action is started.
[string]$url_icinga2agent_path = "https://${neteye4endpoint}/neteyeshare/monitoring/agents/microsoft/icinga"

# Download extra Plugins if String is filled with values
[string]$url_mon_extra_plugins = "${url_icinga2agent_path}/monitoring_plugins/monitoring_plugins.zip"

# Fetch custom nsclient.ini
[string]$url_icinga2agent_nsclient_ini = "${url_icinga2agent_path}/configs/nsclient.ini"

##### Other variables #####
[string]$nsclient_installPath = ""
[string]$nsclient_serviceName = "nscp"
[string]$icinga_installPath = "C:\Program Files\ICINGA2"
[string]$icinga_serviceName = "icinga2"

[string]$log_file = "${workpath}\neteye_agent_deployment.log"

[string]$url_icinga2agent_psm = "${url_icinga2agent_path}/deployment_scripts/Icinga2Agent.psm1"

[string]$url_neteye4director = "https://${neteye4endpoint}/neteye/director/"

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
# Test conditions what actions to perform for Icinga2 Agent: fresh install, update or is all up-to-date

echo "[ ] Starting neteye_agent_deployment script...." | Out-File -FilePath "$log_file" -Append
Write-Host "[ ] Starting neteye_agent_deployment script...."

#Verify is agent installed: install or update 
Write-Host "[ ] Testing if Icinga2 Agent is already installed"
$r = Get-WmiObject Win32_Product | Where {($_.Name -match 'Icinga 2')} 

if ($r -eq $null) {
	Write-Host "[i] NEW INSTALLATION: Icinga2 agent is not installed. Proceeding with new install. Uninstall of Icinga2 agent is not required."
    $action_uninstall_Icinga2_agent = $FALSE
    $action_install_Icinga2_agent = $TRUE

} else {

    #Icinga2Agent is already installed. No update of extra plugins, no install/update of nslcient
    $action_extra_plugins = $FALSE
    $action_custom_nsclient = $FALSE
    $action_install_OCS_agent = $FALSE


    if (($r -ne $null) -and (-not ($r.Version -match $icinga2ver))) {
        
        Write-Host "[i] UPDATE REQUIRED: Icinga2 Agent is installed at version: "$r.Version" Required version: $icinga2ver Updating now..."
        $action_update_Icinga2_agent = $TRUE
        $action_uninstall_Icinga2_agent = $FALSE
        $action_install_Icinga2_agent = $FALSE

    } else {
        Write-Host "[i] Icinga2 Agent is up-to-date. Version $icinga2ver. No uninstall, no update is required."
        $action_update_Icinga2_agent = $FALSE
        $action_uninstall_Icinga2_agent = $FALSE
        $action_install_Icinga2_agent = $FALSE
    }
}



##############################################################################################################
## Start of various actions and operations of powershell script
##############################################################################################################

#Verify preconditions to start:



# Action: Check if i stand within a master or satellite zone
if (( $action_install_Icinga2_agent -eq $TRUE ) -or ($action_update_Icinga2_agent -eq $TRUE)){


    # Where am I as Agent: within a "master Zone"  or a "satellite zone" ?
    Write-Host "[i] Going to check wheter I stand in a master or satellite zone..." 
    
    foreach ($arr_neteye_endpoint in $arr_neteye_endpoints){
        Write-Host "... Checking for neteye 4 endpoint: " $arr_neteye_endpoint[0] " on port " $arr_neteye_endpoint[1] " is master: " $arr_neteye_endpoint[2]

        $connection_test_result = Test-NetConnection -ComputerName $arr_neteye_endpoint[0] -Port $arr_neteye_endpoint[1]
        if ($connection_test_result.TcpTestSucceeded -eq $TRUE){

            Write-Host "[+] Discovered neteye 4 endpoint: " $arr_neteye_endpoint[0] " on port " $arr_neteye_endpoint[1] " is master: " $arr_neteye_endpoint[2]
            $neteye4endpoint = $arr_neteye_endpoint[0]
            $is_neteye4endpoint_master = $arr_neteye_endpoint[2]
        }
    }
}



# Action: Install Icinga2 Agent. 
# Download the required Icinga2 powershell module. This is required only for Agents in Master zone
if ( $action_install_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered AND is Master node: install via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $TRUE)) {

        Write-Host "[i] Installation of Icinga2 Agent via PowerShell Module"

        # Web-get the Icinga2Agent.psm1 from neteye4 share
        $icinga2agent_psm1_file = "$workpath\Icinga2Agent.psm1"

        if ($remote_file_repository -eq "https"){

            Write-Host "Going to download $url_icinga2agent_psm .... -OutFile $icinga2agent_psm1_file"
            Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $icinga2agent_psm1_file

        } elseif ($remote_file_repository -eq "fileshare") {
            Write-Host "TODO: Going to download icinga2agent powershell module from remote fileshare."

        } else {
            Write-Host "Offline mode: Avoid to download $url_icinga2agent_psm."
        }


        if (Test-Path -Path $icinga2agent_psm1_file){
        
            Write-Host "Icinga2Agent.psm1: OK available in $icinga2agent_psm1_file"
        
        } else {
            Write-Host "[!] Icinga2Agent.psm1: NOT AVAILABLE in $icinga2agent_psm1_file. Abort now!"
            exit
        }
        
        Import-Module $workpath"\Icinga2Agent.psm1"
    }
}



# Action : Uninstall of Icinga2 Agent via PowerShell Module
if ( $action_uninstall_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered AND is Master node: UNinstall via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $TRUE)) {
    
        # Perform uninstall
        Write-Host "[i] Perform Uninstallation of Icinga2 Agent now..."
        echo "Perform Uninstallation of Icinga2 Agent now..." | Out-File -FilePath "$log_file" -Append
        Icinga2AgentModule -FullUninstallation -RunUninstaller

    # Endpoint has been discovered AND is Satellite node: UNinstall via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {

        Write-Host "[i] UN-Installation of Icinga2 Agent via msiexec and node setup."
        Write-Host "[!] TODO. Needs to be implemented. Abort here." 

        #Write-Host "Icinga must first be uninstalled"
	    #$MSIArguments = @(
	     #   "/x"
	     #   $r.IdentifyingNumber
	     #   "/qn"
	     #   "/norestart"
	    #)
	    # Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
        # Start-Sleep -s 3
        exit
    }
}



# Action: Install Icinga2 Agent via PowerShell Module
if ( $action_install_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered AND is Master node: install via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $TRUE)) {

        #Sample to override the host address by hostname fqdn in lowercase format
        $json = @{ "address"="&fqdn.lowerCase&"; "display_name"= "&fqdn.lowerCase&"};

        # Perform the setup of Icinga2 Agent via PowerShell module
        $module_call = "-DirectorUrl $url_neteye4director -DirectorAuthToken $neteye4_director_token -IcingaServiceUser $icinga2agent_service_name -NSClientEnableFirewall -NSClientEnableService -RunInstaller -DirectorHostObject $json"

        echo "Invoking Icinga2Agent setup with parameters: $module_call" | Out-File -FilePath "$log_file" -Append
        Write-Host "Invoking Icinga2Agent setup with parameters: $module_call"

        Icinga2AgentModule -DirectorUrl $url_neteye4director -DirectorAuthToken $neteye4_director_token -IcingaServiceUser $icinga2agent_service_name -NSClientEnableFirewall -NSClientEnableService -RunInstaller -DirectorHostObject $json

        #Available parameters:
        #Icinga2AgentModule `
        #-DirectorUrl       $url_neteye4director `
        #-DirectorAuthToken $neteye4_director_token `
        #-RunInstaller `
        #-DirectorHostObject $json `
        #-IgnoreSSLErrors

        # Experimental
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

    # Endpoint has been discovered AND is Satellite node: install via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {

        Write-Host "[i] Installation of Icinga2 Agent via msiexec and node setup."
        Write-Host "[!] TODO. Needs to be implemented. Abort here." 
        exit
    
    } else {
        Write-Host "[!] It was not possible to discover the NetEye 4 endpoint. Not setup of Icinga2 Agent is possible. Abort here." 
        exit
    }
}

# Section: Update Icinga2 Agent via PowerShell Module
if ( $action_update_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered: update of Icinga2 Agent
    # This procedure is valid both for MASTER and SATELLITE zone
    if ( $neteye4endpoint -ne $null ) {

	    Write-Host "[i] Procedding with update of new version of Icinga2 agent to version: $icinga2ver"
        Write-Host "[i] Running command: /i ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi /qn /norestart"
	    $MSIArguments = @(
	        "/i"
	        "${workpath}\Icinga2-v${icinga2ver}-x86_64.msi"
	        "/qn"
	        "/norestart"
	    )
	    Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

        Write-Host "[i] Update completed, Going to Restart Servives"
    
        Start-Sleep -s 3
        Restart-Service -Name icinga2
        Start-Sleep -s 15
        Restart-Service -Name icinga2
        Write-Host "[i] Icinga2 service restarted twice"
    
    } else {
        Write-Host "[!] It was not possible to discover the NetEye 4 endpoint. Not update of Icinga2 Agent is possible. Abort here." 
        exit
    }
}




##############################################################################################################
## Start of additional actions to install additional Plugins, Agents etc.
##############################################################################################################

# Section: Download extra plugins from neteyeshare
if ( $action_extra_plugins -eq $TRUE ){

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
if ( $action_custom_nsclient -eq $TRUE ){

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
If ( $action_extra_plugins -eq $TRUE ) {

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

If (( $action_install_OCS_agent -eq $TRUE ) -and (Test-Path $ocsagent_dst_file)) {
    Write-Host "Removing: $ocsagent_dst_file"
    Remove-Item $ocsagent_dst_file -Force
}

If (( $action_extra_plugins -eq $TRUE ) -and (Test-Path $icinga2_monitoring_plugins_dst_path)) {
    Write-Host "Removing: $icinga2_monitoring_plugins_dst_path"
    Remove-Item $icinga2_monitoring_plugins_dst_path -Force
}

If (( $action_install_Icinga2_agent -eq $TRUE ) -and (Test-Path $icinga2agent_psm1_file)) {
    Write-Host "Removing: $icinga2agent_psm1_file"
    Remove-Item $icinga2agent_psm1_file -Force
}

If (( $action_install_Icinga2_agent -eq $TRUE ) -and (Test-Path "$workpath/Icinga2-*.msi")) {
    Write-Host "Removing: $workpath/Icinga2-*.msi"
    Remove-Item "$workpath/Icinga2-*.msi"
}

Write-Host "Procedure completed. Done. ;o)"
