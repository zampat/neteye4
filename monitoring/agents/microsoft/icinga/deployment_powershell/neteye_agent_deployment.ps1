# Deployment script for monitoring agent deploy for NetEye 3 to NetEye 4 migration projects
#
# This script is specailized to deploy the Icinga2 Agent for operation with NetEye 4 while
# installing and maintaining a running instance of NSClient++ for NetEye 3.
#
# Instructions:
# 1) Configure variables in section param()
#    a) define which actions to perform ($action_*)
#    b) define if download is via https (neteyeshare) or fileshare ($remote_file_repository)
#    c) urls to download agents ($url_*)
#    d) define credentials for https server, icinga2 api and director token
#    e) define Icinga2 infrastructure: ($arr_neteye_endpoints)
# 2) Provide software
#    a) the current script
#    b) curl.exe and libcurl-x64.dll
#
# Changelog:
# 1.1 2020-03-20: 
# - Add switch variables to define the actions to perform
# - Ability to distribute additional monitoring plugins
# - Ability to customize nsclient.ini

# 2020-08-10
# 1. Verify is agent is already installed. If yes, perfom only update and maintain an settings including Certificats, zones.conf and constands.conf
# 2020-08-17: Ability to install Icinga2 Agent in remote zone
# 2020-08-14: Setup Icinga2 agent via msi and run icinga2.exe node setup
# 2020-08-15: Refactoring of parameters, adjust Service "Log on" name after msi install, assemble download-url of monitoring-plugins, nsclient and ocs agent.
# 



# 
# (C) 2019 - 2020 Patrick Zambelli and contributors, Würth Phoenix GmbH
#

param(
   #[string]$workpath="C:\temp",
   [string]$workpath="$Env:temp",

   ###### ACTIONS TO PERFORM ######
   
   # Required in case of invalid HTTPS Server certificate. Then all required files need to be provided in work directory.
   [bool]$action_uninstall_Icinga2_agent = $FALSE,
   [bool]$action_install_Icinga2_agent = $TRUE,
   [bool]$action_update_Icinga2_agent = $TRUE,

   # Download extra Plugins if String is filled with values
   [bool]$action_extra_plugins = $TRUE,

   # Fetch custom nsclient.ini
   [bool]$action_custom_nsclient = $FALSE,

   [bool]$action_install_OCS_agent = $FALSE,


   ###### GLOBAL SETTINGS:  ######
   # Version of Icinga2 Agent
   [string]$icinga2ver="2.11.5",
   
   # The icinga2 service users is overriden.
   [string]$icinga2agent_service_name = "LocalSystem",
   
   # Define how to download files. Supported ources are: https, fileshare, disabled
   [string]$remote_file_repository = "https",

   # NetEye 4 NetEyeShare webserver credentials
   [string]$https_username = "configro",
   [string]$https_password = "gen_password",



   ###### ICINGA2 POWERSHELL MODULE SETTINGS:  ######
   # Variables for Setup via Icinga2 Powershell module (MASTER ZONE)
   [string]$neteye4_director_token = "559ef5ea8263654ecae42a9bcad860ad4dad60d2",



   ###### ICINGA2 API SETTINGS:  ######
   # Variales for Setup via Icinga2 API (SATELLITE ZONE)
   # Icinga2 Agent install/update via Icinga2 API
   [string]$neteye4_icinga_api_user = "ro_user",
   [string]$neteye4_icinga_api_password = "secret",
   [string]$icinga2_agent_hostname_fqdn=((Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain).ToLower(),


   
   ###### OTHER DEFAULT VARIABLES ######
   # Add parent zone and ca server to run check from satellite
   [string]$neteye4endpoint = $null,
   [bool]$is_neteye4endpoint_master = $FALSE,
   [string]$neteye4parent_zone = ""
   
)


# Define available Neteye4 Endpoints 
# ADVICE: Copy-paste names from director zones and endpoint definition !!
# Structure of Array: [string]endpoint fqdn, [int]icinga2 API tcp port, [bool]is master, [string] zone name
$arr_neteye_endpoints = @(
    ("master.domain",5665, $TRUE, "zone",$NULL, "template" ),
    ("satellite.domain",5665, $FALSE, "zone", "satellite2.zone", "template2" )
)


##### Varialbes for HTTPS and FILE-Copy instructions ####
# If variable is set the corresponding action is started.
## Discovery will be done below !
# [string]$url_neteyeshare_base = "https://${neteye4endpoint}
[string]$url_neteyeshare_base = "/neteyeshare/monitoring/agents/microsoft/icinga"
[string]$url_icinga2agent_msi = "${url_neteyeshare_base}/Icinga2-v${icinga2ver}-x86_64.msi"
[string]$url_icinga2agent_psm = "${url_neteyeshare_base}/deployment_scripts/Icinga2Agent.psm1"
# Download extra Plugins if String is filled with values
[string]$url_mon_extra_plugins = "${url_neteyeshare_base}/monitoring_plugins/monitoring_plugins.zip"
# Fetch custom nsclient.ini
[string]$url_icinga2agent_nsclient_ini = "${url_neteyeshare_base}/configs/nsclient.ini"

[string]$url_ocsagent_path = "$url_neteyeshare_base/asset_management/agent/OcsPackage.exe"

# File copy paths
[string]$fs_base = "\\fileshare01.mydomain\neteye\TEMP"
[string]$fs_mon_extra_plugins = "${fs_base}\monitoring_plugins\monitoring_plugins.zip"
[string]$fs_icinga2agent_nsclient_ini = "${fs_base}\configs\nsclient.ini"
[string]$fs_icinga2agent_psm = "${fs_base}\deployment_scripts/Icinga2Agent.psm1"
[string]$fs_icinga2agent_msi = "${fs_base}"







##### Other variables #####
[string]$nsclient_installPath = ""
[string]$nsclient_serviceName = "nscp"
[string]$icinga_installPath = "C:\Program Files\ICINGA2"
[string]$icinga_serviceName = "icinga2"

[string]$log_file = "${workpath}\neteye_agent_deployment.log"


####### Variables for Setup via Icinga2.exe
[string]$CertificatesPath = "C:\ProgramData\icinga2\var\lib\icinga2\certs"
[string]$icinga2bin="C:\Program Files\ICINGA2\sbin\icinga2.exe"



[string]$date_execution = Get-Date -Format "yyyMMd"


#Verify workdir exists
if (-Not (Test-Path $workpath)) {
    New-Item -ItemType Directory -Force -Path $workpath
}


#Start execution
Set-StrictMode -Version Latest
Get-Date | Out-File -FilePath "$log_file" -Append


### ADVICE: Enable this only if really necessary
## Trust invalid ssl certificate
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


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


#######
# Zone Check: is Agent installed in Master or Satellite zone ?
#######
if (( $action_install_Icinga2_agent -eq $TRUE ) -or ($action_update_Icinga2_agent -eq $TRUE) -or ($action_extra_plugins -eq $TRUE)-or ($action_custom_nsclient -eq $TRUE)-or ($action_install_OCS_agent -eq $TRUE)){


    # Where am I as Agent: within a "master Zone"  or a "satellite zone" ?
    Write-Host "[i] Going to check wheter I stand in a master or satellite zone..." 
    
    foreach ($arr_neteye_endpoint in $arr_neteye_endpoints){
        Write-Host "[ ] ... Checking for neteye 4 endpoint: " $arr_neteye_endpoint[0] "(Master: " $arr_neteye_endpoint[2] ") on port " $arr_neteye_endpoint[1]

        $connection_test_result = Test-NetConnection -ComputerName $arr_neteye_endpoint[0] -Port $arr_neteye_endpoint[1]
        if ($connection_test_result.TcpTestSucceeded -eq $TRUE){

            $neteye4endpoint = $arr_neteye_endpoint[0]
            $is_neteye4endpoint_master = $arr_neteye_endpoint[2]
            $neteye4parent_zone = $arr_neteye_endpoint[3]

            if ($arr_neteye_endpoint[4] -ne $NULL){

                $neteye4endpoint2 = $arr_neteye_endpoint[4]

            }

        $host_template = $arr_neteye_endpoint[5]

            

            if ($arr_neteye_endpoint[2] -eq $TRUE){

                Write-Host "[+] Discovered Neteye 4 MASTER Endpoint: " $arr_neteye_endpoint[0] " (Zone: "$arr_neteye_endpoint[3] ")on port " $arr_neteye_endpoint[1]
            } else {

                Write-Host "[+] Discovered Neteye 4 SATELLITE Endpoint: " $arr_neteye_endpoint[0] " (Zone: "$arr_neteye_endpoint[3]") on port " $arr_neteye_endpoint[1]
            }
            
            
        }
    }
}

# Director and self-service API related variables
[string]$url_neteye4director = "https://${neteye4endpoint}/neteye/director/"



# Action: Download Icinga2 Agent .psm1 module or Icinga2 .msi
# Download the required Icinga2 powershell module. This is required only for Agents in Master zone
if (( $action_install_Icinga2_agent -eq $TRUE ) -or ($action_update_Icinga2_agent -eq $TRUE )){

    # Endpoint has been discovered AND is Master node: install via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $TRUE)) {

        # Destination path of the Icinga2Agent.psm1
        $icinga2agent_psm1_file = "$workpath\Icinga2Agent.psm1"

        # Downdload via HTTPS
        if ($remote_file_repository -eq "https"){

            Write-Host "[i] Going to download $url_icinga2agent_psm .... -OutFile $icinga2agent_psm1_file"
            Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $icinga2agent_psm1_file

        # Downdload from remote file-share
        } elseif ($remote_file_repository -eq "fileshare") {

            Write-Host "[i] Going to copy icinga2agent powershell module from remote fileshare."
            Copy-Item -Path "${fs_icinga2agent_psm}" -Destination $icinga2agent_psm1_file

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

    # Endpoint has been discovered AND is Satellite node: install via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {

        # Download of the required Icinga2 MSI file

        # Downdload via HTTPS
        if ($remote_file_repository -eq "https"){

	    Write-Host "[i] Going to download https://${neteye4endpoint}$url_icinga2agent_msi -OutFile ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi"
            #Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $icinga2agent_psm1_file -Proxy $null
	    $parms = '-k', '-s', "https://${neteye4endpoint}$url_icinga2agent_msi", '-o', "${workpath}\Icinga2-v${icinga2ver}-x86_64.msi" $cmdOutput = &".\curl.exe" @parms
	    $cmdOutput = &".\curl.exe" @parms
            
        # Downdload from remote file-share
        } elseif ($remote_file_repository -eq "fileshare") {
        
            Write-Host "[i] Installation of Icinga2 Agent in Satellite zone via .msi file." 
            Write-Host "    Going to download ${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi to Destination $workpath" 
            Copy-Item -Path "${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi" -Destination $workpath

            if (!(Test-Path -LiteralPath ${workpath} )){
                Write-Host "[!] Failure during download from ${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi" 
                return 3
            }
        }
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
        
        $MSIArguments = @(
	       "/x"
	       $r.IdentifyingNumber
	       "/qn"
	       "/norestart"
	    )
	    Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
        Start-Sleep -s 3
    }
}



# Action: Install Icinga2 Agent via PowerShell Module
if ( $action_install_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered AND is Master node: install via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $TRUE)) {

        Write-Host "[i] Installation of Icinga2 Agent via PowerShell Module"

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


    # Endpoint has been discovered AND is SATELLITE node: install via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {
            
        if (!(Test-Path -LiteralPath ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi )){
            Write-Host "[- File ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi already downloaded in $workpath" 
        }


        Write-Host "[i] Going to install Icinga2 Agent with command: msiexec.exe"
        Write-Host "    Running command: /i " + $workpath + "\Icinga2-v${icinga2ver}-x86_64.msi /qn /norestart"
	    $MSIArguments = @(
	        "/i"
	        $workpath + "\Icinga2-v${icinga2ver}-x86_64.msi"
	        "/qn"
	        "/norestart"
	    )
		Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
            
        # Reconfigure the installed Service Log-on name
        Write-Host "[i] Installation completed. Reconfigure Service Log-on to:  ${icinga2agent_service_name}"
        Start-Sleep -s 2
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='icinga2'"
        #$service.StopService()
        $service.Change($null,$null,$null,$null,$null,$null,$icinga2agent_service_name,$null,$null,$null,$null)
        #$service.StartService()
        Start-Sleep -s 2

        Write-Host "[i] Done. Proceeding with configuration setup ..."

        # 2 step: generate ticket from satellite
        # assemble credentials as indicated 
        # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
        $authentication_pair = "${neteye4_icinga_api_user}:${neteye4_icinga_api_password}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
        $base64 = [System.Convert]::ToBase64String($bytes)

        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }

        #$params = -Uri "https://${neteye4endpoint}:5665/v1/actions/generate-ticket" -Headers $headers -Method Post -ContentType "application/json" -Body "{ \"cn\":\"${icinga2_agent_hostname_fqdn}\" }"
        #Write-Host "[ ] Fetching Ticket via Icinga API: $params" 
        #Invoke-WebRequest $params
        #return


        $parms = '-k', '-s', '-u', "${neteye4_icinga_api_user}:${neteye4_icinga_api_password}", '-H', '"Accept: application/json"', '-X', 'POST', "`"https://${neteye4endpoint}:5665/v1/actions/generate-ticket`"", '-d', "`"{ `\`"cn`\`":`\`"${icinga2_agent_hostname_fqdn}`\`" }`""
        Write-Host "[ ] Fetching Ticket via Icinga API: $parms" 
        $cmdOutput = &".\curl.exe" @parms | ConvertFrom-Json

        if (-not ($cmdOutput.results.code -eq "200.0")) {
            Write-Host "[!] Cannot generate ticket. Abort now!"
            exit
        }

        Write-Host "[+] Generated ticket: " $cmdOutput.results.ticket

        $ticket = $cmdOutput.results.ticket

        # 3 step: generate local certificates
        $parms = 'pki', 'new-cert', '--cn', "${icinga2_agent_hostname_fqdn}", '--key', "${CertificatesPath}\${icinga2_agent_hostname_fqdn}.key", '--cert', "${CertificatesPath}\${icinga2_agent_hostname_fqdn}.crt"
        $cmdOutput = &$icinga2bin @parms

        Write-Host "[+] Result of icinga2 pki new-cert command: $cmdOutput"

        if (-not ($cmdOutput -match "Writing X509 certificate")) {
            Write-Host "[!] Cannot generate certificate. Abort now!"
            exit
        }


        # 4 step: get trusted certificates
        $parms = 'pki', 'save-cert', '--host', "${neteye4endpoint}", '--port', '5665', '--trustedcert', "${CertificatesPath}\trusted-parent.crt"
        $cmdOutput = &$icinga2bin @parms

        Write-Host "[+] Result of icinga2 pki save-cert command: $cmdOutput"

        if (-not ($cmdOutput -match "Retrieving X.509 certificate")) {
            Write-Host "[!] Cannot retrieve parent certificate. Abort now!"
            exit
        }


        # 5 step: node setup

        if ($neteye4endpoint2 -ne $NULL){
        
               $parms = 'node', 'setup', '--parent_host', "${neteye4endpoint},5665", '--listen', '::,5665', '--cn', "${icinga2_agent_hostname_fqdn}", '--zone', "${icinga2_agent_hostname_fqdn}", '--parent_zone', """${neteye4parent_zone}""", '--trustedcert', "${CertificatesPath}\trusted-parent.crt", '--endpoint', "${neteye4endpoint},${neteye4endpoint}", '--endpoint', "${neteye4endpoint2},${neteye4endpoint2}" , '--ticket', "${ticket}", '--accept-config', '--accept-commands', '--disable-confd'


        }else{
                
              $parms = 'node', 'setup', '--parent_host', "${neteye4endpoint},5665", '--listen', '::,5665', '--cn', "${icinga2_agent_hostname_fqdn}", '--zone', "${icinga2_agent_hostname_fqdn}", '--parent_zone', """${neteye4parent_zone}""", '--trustedcert', "${CertificatesPath}\trusted-parent.crt", '--endpoint', "${neteye4endpoint},${neteye4endpoint}", '--ticket', "${ticket}", '--accept-config', '--accept-commands', '--disable-confd'

        }

        Write-Host "[i] Starting node setup with parms: " $parms
        $cmdOutput = &$icinga2bin @parms

        Write-Host "[i] Result of icinga2 pki save-cert command: $cmdOutput"

        if ($cmdOutput -match "Make sure to restart Icinga 2") {
            Restart-Service -Name icinga2
            Start-Sleep -s 10
            Restart-Service -Name icinga2
            Write-Host "[+] Done. Icinga2 service restarted twice"
        }
        
        # 6 step: host creation on Director
        $parms = '-k', '-s', '-H', '"Accept: application/json"', '-X', 'POST', "`"https://${neteye4endpoint}/tornado/webhook/event/hsg?token=icinga`"", '-d', "`"{`\`"host_name`\`": `\`"${icinga2_agent_hostname_fqdn}`\`",`\`"host_address`\`": `\`"${icinga2_agent_hostname_fqdn}`\`", `\`"host_template`\`": `\`"${host_template}`\`", `\`"host_status`\`": `\`"0`\`", `\`"output`\`": `\`"Major_problem`\`", `\`"zone`\`": `\`"${neteye4parent_zone}`\`" }`""
        Write-Host "[ ] Creation of Client in Director: $parms" 
        $cmdOutput = &".\curl.exe" @parms 

        
    
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
		$service = Get-WmiObject -Class Win32_Service -Filter "Name='icinga2'"
        #$service.StopService()
        $service.Change($null,$null,$null,$null,$null,$null,$icinga2agent_service_name,$null,$null,$null,$null)
        Write-Host "[i] Update completed, Going to Restart Service"
    
        Start-Sleep -s 3
        Restart-Service -Name icinga2
        Start-Sleep -s 10
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
    $authentication_pair = "${https_username}:${https_password}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $basicAuthValue = "Basic $base64"
    $headers = @{ Authorization = $basicAuthValue }

    # CHECK IF Icinga Agent is installed
    if (Get-Service -Name $icinga_serviceName -ErrorAction SilentlyContinue){

        Write-Host "[i] Going to download and install 'extra monitoring Plugins' ..."

        if (-Not (Test-Path "$icinga_installPath/sbin/scripts")) {
           New-Item -ItemType Directory -Force -Path "$icinga_installPath/sbin/scripts"
        }

        # Install custom monitoring plugins
        $url_mon_extra_plugins = "https://${neteye4endpoint}${url_mon_extra_plugins}"
        Write-Host "[i] Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials, TO: $icinga2_monitoring_plugins_dst_path"
        echo "Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials" | Out-File -FilePath "$log_file" -Append
        Invoke-WebRequest -Uri $url_mon_extra_plugins -OutFile $icinga2_monitoring_plugins_dst_path -Headers $headers

        # monitoring_plugins.zip entpacken
        # Auf PowerShell Version prüfen und ggf. reagieren
        $psversion = $PSVersionTable.PSVersion | select Major
        $min_psversion = New-Object -TypeName System.Version -ArgumentList "5","0","0"

        if ($psversion.Major -lt $min_psversion.Major) {    
            Write-Host "[ ] Unzip of Archive for Powershell Verson before 5.0 starting. Destination Path: $icinga_installPath\sbin\scripts\"
            $shell = New-Object -ComObject shell.application
            $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
            foreach ($item in $zip.items()) {
                $shell.Namespace("$icinga_installPath\sbin\scripts").copyhere($item,0x14)
            }
        } else {
            Write-Host "[ ] Unzip of Archive for Powershell Verson after 5.0 starting. Destination Path: $icinga_installPath\sbin\scripts\"
            Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$icinga_installPath\sbin\scripts" -Force
        }
        Write-Host "[+] Done."
     
    } else {
        Write-Host "[!] Abort of download and install of 'extra monitoring Plugins: Icinga2 Service is NOT installed"
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

    Write-host "[i] Start nsclient++ customizing"

    # assemble credentials as indicated 
    # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
    $authentication_pair = "${https_username}:${https_password}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $basicAuthValue = "Basic $base64"
    $headers = @{ Authorization = $basicAuthValue }

    # Erst prüfen, ob NSClient erkannt wurde
    If ($nsclient_installPath -eq $null) {

        echo "[!] ERROR: Installation-Path of NSClient not found!" | Out-File -FilePath "$log_file" -Append
        Write-Output "[!] ERROR: Installation-Path of NSClient not found!"

    } else {

        # Web-get the nsclient.ini
        $url_icinga2agent_nsclient_ini = "https://${neteye4endpoint}${url_icinga2agent_nsclient_ini}"
        $nsclient_dst_file = "${workpath}\nsclient.ini"

        Write-Host "[i] Going to download of nsclient.ini from $url_icinga2agent_nsclient_ini using credentials TO: $nsclient_dst_file"
        Invoke-WebRequest -Uri $url_icinga2agent_nsclient_ini -OutFile $nsclient_dst_file -Headers $headers

        # If download was successful replace existing .ini file
        if (Test-Path $nsclient_dst_file) {

            Write-Host "[+] Download of nsclient.ini successful."

            Copy-Item "${nsclient_installPath}\nsclient.ini" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_bak    
            Write-Host "[i] Created copy of original nsclient.ini to ${nsclient_installPath}\nsclient.ini.${date_execution}_bak."
    
            Move-Item -Force -Path $nsclient_dst_file -Destination ${nsclient_installPath}\nsclient.ini
            Write-Host "[i] Moved new nsclient.ini to ${nsclient_installPath}\nsclient.ini."

            # Restart service of nsclient++ if currently running
            if (Get-Service -Name $nsclient_serviceName -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"} | Restart-Service){
                Write-Host "[+] Restarted service of NSClient++"
            } else {
                Write-Host "[!] Failure while restarting service of NSClient++. Is Service '$nsclient_serviceName' installed ?"
            }
        }
        Write-Host "[+] Done"
    }
}


#
# Section: Expand NSClient Plugins to NSClient\scripts
If (( $action_custom_nsclient -eq $TRUE ) -and ( $action_extra_plugins -eq $TRUE )) {

    Write-Host "[i] Install additional Monitoring Plugins into NSClient++ install path"

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
    Write-Host "[+] Done."
}


#
# Section: Deployment of OCSAgent
if ( $action_install_OCS_agent -eq $TRUE ){

    Write-Host "[i] Going to deploy OCS agent ..."

    $ocsagent_dst_file = "${workpath}\OcsPackage.exe"
    If (Get-Service -Name "OCS Inventory Service" -ErrorAction SilentlyContinue) {
        Write-Host "[i] OCS Agent is already installed - nothing todo"
    
    } else {

        # assemble credentials as indicated 
        # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
        $authentication_pair = "${https_username}:${https_password}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
        $base64 = [System.Convert]::ToBase64String($bytes)

        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }

        # Download OCSPackage
        $url_ocsagent_path = "https://${neteye4endpoint}${url_ocsagent_path}"

        Write-Host "[i] OCS has to be installed. Downloading OCSPackage from $url_ocsagent_path TO: $ocsagent_dst_file"
        Invoke-WebRequest -Uri $url_ocsagent_path -OutFile $ocsagent_dst_file -Headers $headers

        # If download was successful start installation
        If (Test-Path $ocsagent_dst_file) {

           Write-Host "Start OCS-Agent Installation"
           echo "[+] START OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append

           Start-Process -Wait -FilePath $ocsagent_dst_file 
           Write-Host "END OCS-Agent Installation"
           echo "[+] END OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append

        } else {
            echo "[!] Failure installing OCS Agent."
        }

    }
}


# temp directory clean up
Write-Host "[i] Final step: clean-up of temp-directory"
echo "clean temp-directory" | Out-File -FilePath "$log_file" -Append

If (( $action_install_OCS_agent -eq $TRUE ) -and (Test-Path $ocsagent_dst_file)) {
    Write-Host "Removing: $ocsagent_dst_file"
    Remove-Item $ocsagent_dst_file -Force
}

If (( $action_extra_plugins -eq $TRUE ) -and (Test-Path $icinga2_monitoring_plugins_dst_path)) {
    Write-Host "Removing: $icinga2_monitoring_plugins_dst_path"
    Remove-Item $icinga2_monitoring_plugins_dst_path -Force
}

If (( $icinga2agent_psm1_file -ne $null ) -and ( $action_install_Icinga2_agent -eq $TRUE ) -and (Test-Path $icinga2agent_psm1_file)) {
    Write-Host "Removing: $icinga2agent_psm1_file"
    Remove-Item $icinga2agent_psm1_file -Force
}

If (( $action_install_Icinga2_agent -eq $TRUE ) -and (Test-Path "$workpath/Icinga2-*.msi")) {
    Write-Host "Removing: $workpath/Icinga2-*.msi"
    Remove-Item "$workpath/Icinga2-*.msi"
}

Write-Host "[i] All steps completed. Done. ;o)"
