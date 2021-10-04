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
# 2020-10-20: Icinga2 agents installation in satellite zone and registration of host via call of tornado webhook
# 2020-11-09  Discovery of local machine's association to a subnet. Interation of functions from PSipcalc project. (See copyright note)
# 



# 
# (C) 2019 - 2020 Patrick Zambelli and contributors, Wuerth Phoenix GmbH
# (C) to Joakim Svendsen https://github.com/EliteLoser from functions from PSipcalc
## https://www.powershelladmin.com/wiki/Calculate_and_enumerate_subnets_with_PSipcalc
## https://github.com/EliteLoser/PSipcalc/blob/master/PSipcalc.ps1
#

# Security policies might enforce TLS 1.2 in order to allow Invoke-Webrequest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

param(
   [string]$workpath="C:\temp",
   #[string]$workpath="$Env:temp",
   #[string]$workpath=Get-Location,

   ###### ACTIONS TO PERFORM ######
   
   # Required in case of invalid HTTPS Server certificate. Then all required files need to be provided in work directory.
   $action_force_reinstall_Icinga2_agent=$FALSE,

   # Download extra Plugins if String is filled with values
   $action_force_reinstall_extra_plugins=$FALSE,

   # Fetch custom nsclient.ini
   [bool]$action_custom_nsclient = $TRUE,

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
   [string]$https_password = "genrated_password",



   ###### ICINGA2 POWERSHELL MODULE SETTINGS:  ######
   # Variables for Setup via Icinga2 Powershell module (MASTER ZONE)
   [string]$neteye4_director_token = "xxxxxxxxxxxxxxxxxxxxxxxxxx",



   ###### ICINGA2 API SETTINGS:  ######
   # Variales for Setup via Icinga2 API (SATELLITE ZONE)
   # Icinga2 Agent install/update via Icinga2 API
   [string]$neteye4_icinga_api_user = "host4create",
   [string]$neteye4_icinga_api_password = "xxxxxxxxxxxxxxxx",
   [string]$icinga2_agent_hostname_fqdn=((Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain).ToLower(),
   [string]$icinga2_agent_hostname_short=((Get-WmiObject win32_computersystem).DNSHostName).ToLower(),


   
   ###### OTHER DEFAULT VARIABLES ######
   # Add parent zone and ca server to run check from satellite
   [string]$neteye4endpoint = $null,
   [bool]$is_neteye4endpoint_master = $FALSE,
   [string]$neteye4parent_zone = ""
   
)

# Define available Neteye4 Endpoints 
# HINT: Copy-paste names from director zones and endpoint definition !!
#
# INSTRUCTIONS: 
# - For Endpoint MASTER = TRUE define the IP of Master/cluster node
# - For Endpoint MASTER = FALSE define the IP of the endpoint(s) in zone
#
# Advice:
# IF there are errors during local IP discovery or subnet can not be resolved:
# "Default" fallback: The first element of array used.
#
# Structure of Array: arr_subnet_ranges
# [0] [string]IP subnet, 
# [1] [string]endpoint 1 fqdn,
# [2] [string]endpoint 2 fqdn,
# [3] [string] zone name, 
# [4] [bool]is master zone,
# [5] [string] host template
[array]$arr_subnet_ranges = @(
    ("10.10.0.0/15", "myclusterhost.mydomain.lan", $null, "neteye_zone_master", $TRUE, "" ),
    ("10.90.90.0/21", "satellite1.mydomain.lan", "satellite2.mydomain.lan", "sat_neteye_zone1", $FALSE , "generic-agent-windows-zone1"),
    ("192.168.0.0/24", "dmz1.mydomain.lan", "dmz2.mydomain.lan", "sat_dmz_zone", $FALSE , "generic-agent-windows-dmz")
)

# Define available Neteye4 Endpoints 
# ADVICE: Copy-paste names from director zones and endpoint definition !!
# Structure of Array: [string]endpoint fqdn, [int]icinga2 API tcp port, [bool]is master, [string] zone name
#
# This list is not in use anymore
#
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
[string]$neteye4endpoint2 = $NULL
[string]$icinga2agent_psm1_file = $NULL

[string]$logdate = (Get-Date -Format "yyyyMMdd")
[string]$log_file = "${workpath}\neteye_agent_deployment_$logdate.log"


####### Variables for Setup via Icinga2.exe
[string]$CertificatesPath = "C:\ProgramData\icinga2\var\lib\icinga2\certs"
[string]$icinga2bin="C:\Program Files\ICINGA2\sbin\icinga2.exe"


############# END OF VARIABLES DEFINITION ###############

[string]$date_execution = Get-Date -Format "yyyMMd"


##############################################################################################################
##### Functions
##############################################################################################################

### Logging action
function log_message {

    param ($message)
    echo "$message" | Out-File -FilePath "$log_file" -Append
    Write-Host "$message"
} 



#### Functions from PSipcalc
## https://www.powershelladmin.com/wiki/Calculate_and_enumerate_subnets_with_PSipcalc
## https://github.com/EliteLoser/PSipcalc/blob/master/PSipcalc.ps1
#
# This is a regex I made to match an IPv4 address precisely ( http://www.powershelladmin.com/wiki/PowerShell_regex_to_accurately_match_IPv4_address_%280-255_only%29 )
$IPv4Regex = '(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)'

function Convert-IPToBinary
{
    param(
        [string] $IP
    )
    $IP = $IP.Trim()
    if ($IP -match "\A${IPv4Regex}\z")
    {
        try
        {
            return ($IP.Split('.') | ForEach-Object { [System.Convert]::ToString([byte] $_, 2).PadLeft(8, '0') }) -join ''
        }
        catch
        {
            Write-Warning -Message "Error converting '$IP' to a binary string: $_"
            return $Null
        }
    }
    else
    {
        Write-Warning -Message "Invalid IP detected: '$IP'."
        return $Null
    }
}


function Convert-BinaryToIP
{
    param(
        [string] $Binary
    )
    $Binary = $Binary -replace '\s+'
    if ($Binary.Length % 8)
    {
        Write-Warning -Message "Binary string '$Binary' is not evenly divisible by 8."
        return $Null
    }
    [int] $NumberOfBytes = $Binary.Length / 8
    $Bytes = @(foreach ($i in 0..($NumberOfBytes-1))
    {
        try
	{
	    #$Bytes += # skipping this and collecting "outside" seems to make it like 10 % faster
            [System.Convert]::ToByte($Binary.Substring(($i * 8), 8), 2)
	}
        catch
        {
            Write-Warning -Message "Error converting '$Binary' to bytes. `$i was $i."
            return $Null
        }
    })
    return $Bytes -join '.'
}

function Get-ProperCIDR
{
    param(
        [string] $CIDRString
    )
    $CIDRString = $CIDRString.Trim()
    $o = '' | Select-Object -Property IP, NetworkLength
    if ($CIDRString -match "\A(?<IP>${IPv4Regex})\s*/\s*(?<NetworkLength>\d{1,2})\z")
    {
        # Could have validated the CIDR in the regex, but this is more informative.
        if ([int] $Matches['NetworkLength'] -lt 0 -or [int] $Matches['NetworkLength'] -gt 32)
        {
            Write-Warning "Network length out of range (0-32) in CIDR string: '$CIDRString'."
            return
        }
        $o.IP = $Matches['IP']
        $o.NetworkLength = $Matches['NetworkLength']
    }
    elseif ($CIDRString -match "\A(?<IP>${IPv4Regex})[\s/]+(?<SubnetMask>${IPv4Regex})\z")
    {
        $o.IP = $Matches['IP']
        $SubnetMask = $Matches['SubnetMask']
        if (-not ($BinarySubnetMask = Convert-IPToBinary $SubnetMask))
        {
            return # warning displayed by Convert-IPToBinary, nothing here
        }
        # Some validation of the binary form of the subnet mask, 
        # to check that there aren't ones after a zero has occurred (invalid subnet mask).
        # Strip all leading ones, which means you either eat 32 1s and go to the end (255.255.255.255),
        # or you hit a 0, and if there's a 1 after that, we've got a broken subnet mask, amirite.
        if ((($BinarySubnetMask) -replace '\A1+') -match '1')
        {
            Write-Warning -Message "Invalid subnet mask in CIDR string '$CIDRString'. Subnet mask: '$SubnetMask'."
            return
        }
        $o.NetworkLength = [regex]::Matches($BinarySubnetMask, '1').Count
    }
    else
    {
        Write-Warning -Message "Invalid CIDR string: '${CIDRString}'. Valid examples: '192.168.1.0/24', '10.0.0.0/255.0.0.0'."
        return
    }
    # Check if the IP is all ones or all zeroes (not allowed: http://www.cisco.com/c/en/us/support/docs/ip/routing-information-protocol-rip/13788-3.html )
    if ($o.IP -match '\A(?:(?:1\.){3}1|(?:0\.){3}0)\z')
    {
        Write-Warning "Invalid IP detected in CIDR string '${CIDRString}': '$($o.IP)'. An IP can not be all ones or all zeroes."
        return
    }
    return $o
}


function Get-NetworkInformationFromProperCIDR
{
    param(
        [psobject] $CIDRObject
    )
    $o = '' | Select-Object -Property IP, NetworkLength, SubnetMask, NetworkAddress, HostMin, HostMax, 
        Broadcast, UsableHosts, TotalHosts, IPEnumerated, BinaryIP, BinarySubnetMask, BinaryNetworkAddress,
        BinaryBroadcast
    $o.IP = [string] $CIDRObject.IP
    $o.BinaryIP = Convert-IPToBinary $o.IP
    $o.NetworkLength = [int32] $CIDRObject.NetworkLength
    $o.SubnetMask = Convert-BinaryToIP ('1' * $o.NetworkLength).PadRight(32, '0')
    $o.BinarySubnetMask = ('1' * $o.NetworkLength).PadRight(32, '0')
    $o.BinaryNetworkAddress = $o.BinaryIP.SubString(0, $o.NetworkLength).PadRight(32, '0')
    if ($Contains)
    {
        if ($Contains -match "\A${IPv4Regex}\z")
        {
            # Passing in IP to test, start binary and end binary.
            return Test-IPIsInNetwork $Contains $o.BinaryNetworkAddress $o.BinaryNetworkAddress.SubString(0, $o.NetworkLength).PadRight(32, '1')
        }
        else
        {
            Write-Error "Invalid IPv4 address specified with -Contains"
            return
        }
    }
    $o.NetworkAddress = Convert-BinaryToIP $o.BinaryNetworkAddress
    if ($o.NetworkLength -eq 32 -or $o.NetworkLength -eq 31)
    {
        $o.HostMin = $o.IP
    }
    else
    {
        $o.HostMin = Convert-BinaryToIP ([System.Convert]::ToString(([System.Convert]::ToInt64($o.BinaryNetworkAddress, 2) + 1), 2)).PadLeft(32, '0')
    }
    #$o.HostMax = Convert-BinaryToIP ([System.Convert]::ToString((([System.Convert]::ToInt64($o.BinaryNetworkAddress.SubString(0, $o.NetworkLength)).PadRight(32, '1'), 2) - 1), 2).PadLeft(32, '0'))
    #$o.HostMax = 
    [string] $BinaryBroadcastIP = $o.BinaryNetworkAddress.SubString(0, $o.NetworkLength).PadRight(32, '1') # this gives broadcast... need minus one.
    $o.BinaryBroadcast = $BinaryBroadcastIP
    [int64] $DecimalHostMax = [System.Convert]::ToInt64($BinaryBroadcastIP, 2) - 1
    [string] $BinaryHostMax = [System.Convert]::ToString($DecimalHostMax, 2).PadLeft(32, '0')
    $o.HostMax = Convert-BinaryToIP $BinaryHostMax
    $o.TotalHosts = [int64][System.Convert]::ToString(([System.Convert]::ToInt64($BinaryBroadcastIP, 2) - [System.Convert]::ToInt64($o.BinaryNetworkAddress, 2) + 1))
    $o.UsableHosts = $o.TotalHosts - 2
    # ugh, exceptions for network lengths from 30..32
    if ($o.NetworkLength -eq 32)
    {
        $o.Broadcast = $Null
        $o.UsableHosts = [int64] 1
        $o.TotalHosts = [int64] 1
        $o.HostMax = $o.IP
    }
    elseif ($o.NetworkLength -eq 31)
    {
        $o.Broadcast = $Null
        $o.UsableHosts = [int64] 2
        $o.TotalHosts = [int64] 2
        # Override the earlier set value for this (bloody exceptions).
        [int64] $DecimalHostMax2 = [System.Convert]::ToInt64($BinaryBroadcastIP, 2) # not minus one here like for the others
        [string] $BinaryHostMax2 = [System.Convert]::ToString($DecimalHostMax2, 2).PadLeft(32, '0')
        $o.HostMax = Convert-BinaryToIP $BinaryHostMax2
    }
    elseif ($o.NetworkLength -eq 30)
    {
        $o.UsableHosts = [int64] 2
        $o.TotalHosts = [int64] 4
        $o.Broadcast = Convert-BinaryToIP $BinaryBroadcastIP
    }
    else
    {
        $o.Broadcast = Convert-BinaryToIP $BinaryBroadcastIP
    }
    if ($Enumerate)
    {
        $IPRange = @(Get-IPRange2 $o.BinaryNetworkAddress $o.BinaryNetworkAddress.SubString(0, $o.NetworkLength).PadRight(32, '1'))
        if ((31, 32) -notcontains $o.NetworkLength )
        {
            $IPRange = $IPRange[1..($IPRange.Count-1)] # remove first element
            $IPRange = $IPRange[0..($IPRange.Count-2)] # remove last element
        }
        $o.IPEnumerated = $IPRange
    }
    else {
        $o.IPEnumerated = @()
    }
    return $o
}

function Test-IPIsInNetwork {
    param(
        [string] $IP,
        [string] $StartBinary,
        [string] $EndBinary
    )
    $TestIPBinary = Convert-IPToBinary $IP
    [int64] $TestIPInt64 = [System.Convert]::ToInt64($TestIPBinary, 2)
    [int64] $StartInt64 = [System.Convert]::ToInt64($StartBinary, 2)
    [int64] $EndInt64 = [System.Convert]::ToInt64($EndBinary, 2)
    if ($TestIPInt64 -ge $StartInt64 -and $TestIPInt64 -le $EndInt64)
    {
        return $True
    }
    else
    {
        return $False
    }
}



##############################################################################################################
### End of functions
##############################################################################################################

#Verify workdir exists
if (-Not (Test-Path $workpath)) {
    New-Item -ItemType Directory -Force -Path $workpath
}







#Start execution
Set-StrictMode -Version Latest
$datetime = Get-Date
log_message -message ">>> NetEye deployment script start: $datetime"


#Logging of parameters
log_message -message "[i] Parameter: Force re-install of extra plugins: $action_force_reinstall_extra_plugins"



### ADVICE: Enable this only if really necessary
## Trust invalid ssl certificate
try {
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

} catch {

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}




##############################################################################################################
# Test conditions what actions to perform for Icinga2 Agent: fresh install, update or is all up-to-date
##############################################################################################################


#Verify is agent installed: install or update 
log_message -message "[ ] Testing if Icinga2 Agent is already installed"

$r = Get-WmiObject Win32_Product | Where {($_.Name -match 'Icinga 2')} 


# Instantiate custom variables
[bool]$action_uninstall_Icinga2_agent = $FALSE
[bool]$action_install_Icinga2_agent = $TRUE
[bool]$action_update_Icinga2_agent = $TRUE
[bool]$action_extra_plugins = $TRUE


# Force the re-installation of the Icinga2 Agent if defined by parameter
if ($action_force_reinstall_Icinga2_agent -eq $TRUE){
    log_message -message "[i] FORCE RE-INSTALLATION: Icinga2 agent will now be uninstalled and then proceeding with a fresh install."
    $action_uninstall_Icinga2_agent = $TRUE
    $action_install_Icinga2_agent = $TRUE
    $action_update_Icinga2_agent = $FALSE

} elseif ($r -eq $NULL) {
    log_message -message "[i] NEW INSTALLATION: Icinga2 agent is not installed. Proceeding with new install. Uninstall of Icinga2 agent is not required."
    $action_uninstall_Icinga2_agent = $FALSE
    $action_install_Icinga2_agent = $TRUE

} else {

    #Icinga2Agent is already installed. No update of extra plugins, no install/update of nslcient
    $action_extra_plugins = $FALSE
    $action_custom_nsclient = $FALSE
    $action_install_OCS_agent = $FALSE


    if (($r -ne $null) -and (-not ($r.Version -match $icinga2ver))) {
        
        log_message -message "[i] UPDATE REQUIRED: Icinga2 Agent is installed at version: "$r.Version" Required version: $icinga2ver Updating now..."
        $action_update_Icinga2_agent = $TRUE
        $action_uninstall_Icinga2_agent = $FALSE
        $action_install_Icinga2_agent = $FALSE

    } else {
        log_message -message "[i] Icinga2 Agent is up-to-date. Version $icinga2ver. No uninstall, no update is required."
        $action_update_Icinga2_agent = $FALSE
        $action_uninstall_Icinga2_agent = $FALSE
        $action_install_Icinga2_agent = $FALSE
    }
}


# Force the installation of the "extra plugin" files if defined by parameter
if ($action_force_reinstall_extra_plugins -eq $TRUE){
    [bool]$action_extra_plugins = $TRUE
    log_message -message "[i] DO force reinstall of extra plugins. value: $action_force_reinstall_extra_plugins"
}



##############################################################################################################
## Start of various actions and operations of powershell script
##############################################################################################################




##############################################################################################################
# Zone Check: is Agent installed in Master or Satellite zone ?
##############################################################################################################

if (( $action_install_Icinga2_agent -eq $TRUE ) -or ($action_update_Icinga2_agent -eq $TRUE) -or ($action_extra_plugins -eq $TRUE)-or ($action_custom_nsclient -eq $TRUE)-or ($action_install_OCS_agent -eq $TRUE)){

    # Where am I as Agent: within a "master Zone"  or a "satellite zone" ?
    log_message -message "[i] Local IP vs. Subnet discovery: Going to check wheter I stand in a master or satellite zone..." 

    
    [string[]]$my_IPs = @(Get-NetIPAddress -AddressState Preferred -AddressFamily IPv4 | %{$_.IPAddress})

    $IP_Subnet_discovered = $FALSE
    $IP_Subnet_CIDR = ""
    $IP_Address_Matched = ""

    if (( $my_IPs -eq $null ) -or ( $my_IPs.Length -lt 1 )) {
        log_message -message "[-] Error: Local IP Addresses discovery failed. NO IP Addresses found."
    }

    for ($i=0; $i -lt $my_IPs.Length; $i++){

        if ($my_IPs[$i] -eq "127.0.0.1") {
            continue
        }
        $Contains = $my_IPs[$i]

        for ($x=0; $x -lt $arr_subnet_ranges.Length; $x++){
            
            [array] $arr_subnet2test = $arr_subnet_ranges[$x]

            # Script built on "contains" logic from PSipcalc
            ## https://www.powershelladmin.com/wiki/Calculate_and_enumerate_subnets_with_PSipcalc
            ## Source code:
            ## https://github.com/EliteLoser/PSipcalc/blob/master/PSipcalc.ps1
            #$arr_subnet2test | ForEach-Object { Get-ProperCIDR $_[0] } | ForEach-Object { $res = Get-NetworkInformationFromProperCIDR $_ }
            Get-ProperCIDR $arr_subnet2test[0] | ForEach-Object { $IP_Subnet_discovered = Get-NetworkInformationFromProperCIDR $_ }
        
            if ( $IP_Subnet_discovered -eq $TRUE){

                $IP_Subnet_CIDR = $arr_subnet2test[0]
                $IP_Address_Matched = $Contains

                # Structure of Array: arr_subnet_ranges
                # [0] [string]IP subnet, 
                # [1] [string]endpoint 1 fqdn,
                # [2] [string]endpoint 2 fqdn,
                # [3] [string] zone name, 
                # [4] [bool]is master zone,
                # [5] [string] host template
                
                $neteye4endpoint = $arr_subnet2test[1]
                if ($arr_subnet2test[2] -ne $NULL){
                    $neteye4endpoint2 = $arr_subnet2test[2]
                }
                $neteye4parent_zone = $arr_subnet2test[3]
                $is_neteye4endpoint_master = $arr_subnet2test[4]
                $host_template = $arr_subnet2test[5]

                log_message "Found: IP $Contains is in subnet $arr_subnet2test."
            }
        }
    }

    # FAllback: No Subnet discoverd -> FAllback rule
    if ( $IP_Subnet_discovered -ne $TRUE ){

        # Default rule: take the first element of Endpoints
        [array] $arr_subnet2test = $arr_subnet_ranges[0]
        $neteye4endpoint = $arr_subnet2test[1]
        if ($arr_subnet2test[2] -ne $NULL){
            $neteye4endpoint2 = $arr_subnet2test[2]
        }
        $neteye4parent_zone = $arr_subnet2test[3]
        $is_neteye4endpoint_master = $arr_subnet2test[4]
        $host_template = $arr_subnet2test[5]
        log_message -message "[!] Proceeding with Fallback logice: Take default Endpoint: $neteye4endpoint and Zone $neteye4parent_zone"
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

            log_message -message "[i] Going to download https://${neteye4endpoint}$url_icinga2agent_psm .... -OutFile $icinga2agent_psm1_file"
            Invoke-WebRequest -Uri https://${neteye4endpoint}$url_icinga2agent_psm -OutFile $icinga2agent_psm1_file

        # Downdload from remote file-share
        } elseif ($remote_file_repository -eq "fileshare") {

            log_message -message "[i] Going to copy icinga2agent powershell module from remote fileshare."
            Copy-Item -Path "${fs_icinga2agent_psm}" -Destination $icinga2agent_psm1_file

        } else {

            log_message -message  "Offline mode: Avoid to download $url_icinga2agent_psm."
        }


        if (Test-Path -Path $icinga2agent_psm1_file){
        
            log_message -message "Icinga2Agent.psm1: OK available in $icinga2agent_psm1_file"
        
        } else {
            log_message -message "[!] Icinga2Agent.psm1: NOT AVAILABLE in $icinga2agent_psm1_file. Abort now!"
            exit
        }
        
        Import-Module $workpath"\Icinga2Agent.psm1"

    # Endpoint has been discovered AND is Satellite node: install via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {

        # Download of the required Icinga2 MSI file

        # Downdload via HTTPS
        if ($remote_file_repository -eq "https"){

	    log_message -message "[i] Going to download https://${neteye4endpoint}$url_icinga2agent_msi -OutFile ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi"
            #Invoke-WebRequest -Uri $url_icinga2agent_psm -OutFile $icinga2agent_psm1_file -Proxy $null
	    $parms = '-k', '-s', "https://${neteye4endpoint}$url_icinga2agent_msi", '-o', "${workpath}\Icinga2-v${icinga2ver}-x86_64.msi"
	    $cmdOutput = &"$workpath\curl.exe" @parms
            
        # Downdload from remote file-share
        } elseif ($remote_file_repository -eq "fileshare") {
        
            log_message -message "[i] Installation of Icinga2 Agent in Satellite zone via .msi file." 
            log_message -message "    Going to download ${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi to Destination $workpath" 
            Copy-Item -Path "${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi" -Destination $workpath

            if (!(Test-Path -LiteralPath ${workpath} )){
                log_message -message "[!] Failure during download from ${fs_icinga2agent_msi}\Icinga2-v${icinga2ver}-x86_64.msi" 
                return 3
            }
        }
    }
}



# Action : Uninstall of Icinga2 Agent via PowerShell Module
if ( $action_uninstall_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered AND is Master node: UNinstall via Icinga2 PowerShell Module
    if (( $neteye4endpoint -ne $null ) -and ($r -ne $NULL) -and ( $is_neteye4endpoint_master -eq $TRUE)) {
    
        # Perform uninstall
        log_message -message "[i] Perform Uninstallation of Icinga2 Agent now..."
        echo "Perform Uninstallation of Icinga2 Agent now..." | Out-File -FilePath "$log_file" -Append
        Icinga2AgentModule -FullUninstallation -RunUninstaller

    # Endpoint has been discovered AND is Satellite node: UNinstall via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {

        log_message -message "[i] UN-Installation of Icinga2 Agent via msiexec and node setup."
        
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

        log_message -message "[i] Installation of Icinga2 Agent via PowerShell Module"

        #Sample to override the host address by hostname fqdn in lowercase format
        $json = @{ "address"="&fqdn.lowerCase&"; "display_name"= "&fqdn.lowerCase&"};

        # Perform the setup of Icinga2 Agent via PowerShell module
        $module_call = "-DirectorUrl $url_neteye4director -DirectorAuthToken $neteye4_director_token -IcingaServiceUser $icinga2agent_service_name -NSClientEnableFirewall -NSClientEnableService -RunInstaller -DirectorHostObject $json"

        echo "Invoking Icinga2Agent setup with parameters: $module_call" | Out-File -FilePath "$log_file" -Append
        log_message -message "Invoking Icinga2Agent setup with parameters: $module_call"

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
        #    log_message -message "Reconfiguring Icinga2 Agent service login account to: $icinga2agent_service_name"
        #    $service = Get-WmiObject -Class Win32_Service -Filter "Name='icinga2'"
        #    $service.StopService()
        #    $service.Change($null,$null,$null,$null,$null,$null,$icinga2agent_service_name,$null,$null,$null,$null)
        #    $service.StartService()
        #}


    # Endpoint has been discovered AND is SATELLITE node: install via msiexec and perform node setup
    } elseif (( $neteye4endpoint -ne $null ) -and ( $is_neteye4endpoint_master -eq $FALSE)) {
            
        if (!(Test-Path -LiteralPath ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi )){
            log_message -message "[- File ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi already downloaded in $workpath" 
        }


        log_message -message "[i] Going to install Icinga2 Agent with command: msiexec.exe"
        log_message -message "    Running command: /i " + $workpath + "\Icinga2-v${icinga2ver}-x86_64.msi /qn /norestart"
	    $MSIArguments = @(
	        "/i"
	        $workpath + "\Icinga2-v${icinga2ver}-x86_64.msi"
	        "/qn"
	        "/norestart"
	    )
		Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
            
        # Reconfigure the installed Service Log-on name
        log_message -message "[i] Installation completed. Reconfigure Service Log-on to:  ${icinga2agent_service_name}"
        Start-Sleep -s 2
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='icinga2'"
		IF ($service) {
			log_message -message "[i] Service icinga2 successfully installed"
		}
		else {
			log_message -message "[i] Service icinga2 not installed"
			log_message -message "[i] the installation will be canceled in 15 seconds"
			Start-Sleep -s 15
			Exit 1
		}
        #$service.StopService()
        $service.Change($null,$null,$null,$null,$null,$null,$icinga2agent_service_name,$null,$null,$null,$null)
        #$service.StartService()
        Start-Sleep -s 2

        log_message -message "[i] Done. Proceeding with configuration setup ..."

        # 2 step: generate ticket from satellite
        # assemble credentials as indicated 
        # https://stackoverflow.com/questions/27951561/use-invoke-webrequest-with-a-username-and-password-for-basic-authentication-on-t
        $authentication_pair = "${neteye4_icinga_api_user}:${neteye4_icinga_api_password}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($authentication_pair)
        $base64 = [System.Convert]::ToBase64String($bytes)

        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }

        #$params = -Uri "https://${neteye4endpoint}:5665/v1/actions/generate-ticket" -Headers $headers -Method Post -ContentType "application/json" -Body "{ \"cn\":\"${icinga2_agent_hostname_short}\" }"
        #log_message -message "[ ] Fetching Ticket via Icinga API: $params" 
        #Invoke-WebRequest $params
        #return


        $parms = '-k', '-s', '-u', "${neteye4_icinga_api_user}:${neteye4_icinga_api_password}", '-H', '"Accept: application/json"', '-X', 'POST', "`"https://${neteye4endpoint}:5665/v1/actions/generate-ticket`"", '-d', "`"{ `\`"cn`\`":`\`"${icinga2_agent_hostname_short}`\`" }`""
        log_message -message "[ ] Fetching Ticket via Icinga API: $parms" 
        $cmdOutput = &"$workpath\curl.exe" @parms | ConvertFrom-Json

        if (-not ($cmdOutput.results.code -eq "200.0")) {
            log_message -message "[!] Cannot generate ticket. Abort now!"
            exit
        }

        log_message -message "[+] Generated ticket: " $cmdOutput.results.ticket

        $ticket = $cmdOutput.results.ticket

        # 3 step: generate local certificates
        $parms = 'pki', 'new-cert', '--cn', "${icinga2_agent_hostname_short}", '--key', "${CertificatesPath}\${icinga2_agent_hostname_short}.key", '--cert', "${CertificatesPath}\${icinga2_agent_hostname_short}.crt"
        $cmdOutput = &$icinga2bin @parms

        log_message -message "[+] Result of icinga2 pki new-cert command: $cmdOutput"

        if (-not ($cmdOutput -match "Writing X509 certificate")) {
            log_message -message "[!] Cannot generate certificate. Abort now!"
            exit
        }


        # 4 step: get trusted certificates
        $parms = 'pki', 'save-cert', '--host', "${neteye4endpoint}", '--port', '5665', '--trustedcert', "${CertificatesPath}\trusted-parent.crt"
        $cmdOutput = &$icinga2bin @parms

        log_message -message "[+] Result of icinga2 pki save-cert command: $cmdOutput"

        if (-not ($cmdOutput -match "Retrieving X.509 certificate")) {
            log_message -message "[!] Cannot retrieve parent certificate. Abort now!"
            exit
        }


        # 5 step: node setup

        IF([string]::IsNullOrWhiteSpace($neteye4endpoint2)) {
        
              $parms = 'node', 'setup', '--parent_host', "${neteye4endpoint},5665", '--listen', '::,5665', '--cn', "${icinga2_agent_hostname_short}", '--zone', "${icinga2_agent_hostname_short}", '--parent_zone', """${neteye4parent_zone}""", '--trustedcert', "${CertificatesPath}\trusted-parent.crt", '--endpoint', "${neteye4endpoint},${neteye4endpoint}", '--ticket', "${ticket}", '--accept-config', '--accept-commands', '--disable-confd'



        }else{
              $parms = 'node', 'setup', '--parent_host', "${neteye4endpoint},5665", '--listen', '::,5665', '--cn', "${icinga2_agent_hostname_short}", '--zone', "${icinga2_agent_hostname_short}", '--parent_zone', """${neteye4parent_zone}""", '--trustedcert', "${CertificatesPath}\trusted-parent.crt", '--endpoint', "${neteye4endpoint},${neteye4endpoint}", '--endpoint', "${neteye4endpoint2},${neteye4endpoint2}" , '--ticket', "${ticket}", '--accept-config', '--accept-commands', '--disable-confd'
 

        }

        log_message -message "[i] Starting node setup with parms: " $parms
        $cmdOutput = &$icinga2bin @parms

        log_message -message "[i] Result of icinga2 pki save-cert command: $cmdOutput"

        if ($cmdOutput -match "Make sure to restart Icinga 2") {
            Restart-Service -Name icinga2
            Start-Sleep -s 10
            Restart-Service -Name icinga2
            log_message -message "[+] Done. Icinga2 service restarted twice"
        }
        
        # 6 step: host creation on Director
        $parms = '-k', '-s', '-H', '"Accept: application/json"', '-X', 'POST', "`"https://${neteye4endpoint}/tornado/webhook/event/hsg?token=icinga`"", '-d', "`"{`\`"host_name`\`": `\`"${icinga2_agent_hostname_short}`\`",`\`"host_address`\`": `\`"${icinga2_agent_hostname_fqdn}`\`", `\`"host_template`\`": `\`"${host_template}`\`", `\`"host_status`\`": `\`"0`\`", `\`"output`\`": `\`"Major_problem`\`", `\`"zone`\`": `\`"${neteye4parent_zone}`\`" }`""
        log_message -message "[ ] Creation of Client in Director: $parms" 
        $cmdOutput = &"$workpath\curl.exe" @parms 

        
    
    } else {
        log_message -message "[!] It was not possible to discover the NetEye 4 endpoint. Not setup of Icinga2 Agent is possible. Abort here." 
        exit
    }
}

# Section: Update Icinga2 Agent via PowerShell Module
if ( $action_update_Icinga2_agent -eq $TRUE ){

    # Endpoint has been discovered: update of Icinga2 Agent
    # This procedure is valid both for MASTER and SATELLITE zone
    if ( $neteye4endpoint -ne $null ) {

	    log_message -message "[i] Procedding with update of new version of Icinga2 agent to version: $icinga2ver"
        log_message -message "[i] Running command: /i ${workpath}\Icinga2-v${icinga2ver}-x86_64.msi /qn /norestart"
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
        log_message -message "[i] Update completed, Going to Restart Service"
    
        Start-Sleep -s 3
        Restart-Service -Name icinga2
        Start-Sleep -s 10
        Restart-Service -Name icinga2
        log_message -message "[i] Icinga2 service restarted twice"
    
    } else {
        log_message -message "[!] It was not possible to discover the NetEye 4 endpoint. Not update of Icinga2 Agent is possible. Abort here." 
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

        log_message -message "[i] Going to download and install 'extra monitoring Plugins' ..."

        if (-Not (Test-Path "$icinga_installPath/sbin/scripts")) {
           New-Item -ItemType Directory -Force -Path "$icinga_installPath/sbin/scripts"
        }

        # Install custom monitoring plugins
        $url_mon_extra_plugins = "https://${neteye4endpoint}${url_mon_extra_plugins}"
        log_message -message "[i] Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials, TO: $icinga2_monitoring_plugins_dst_path"
        echo "Download of monitoring_plugins.zip from $url_mon_extra_plugins using credentials" | Out-File -FilePath "$log_file" -Append
        Invoke-WebRequest -Uri $url_mon_extra_plugins -OutFile $icinga2_monitoring_plugins_dst_path -Headers $headers

        # monitoring_plugins.zip entpacken
        # Auf PowerShell Version prüfen und ggf. reagieren
        $psversion = $PSVersionTable.PSVersion | select Major
        $min_psversion = New-Object -TypeName System.Version -ArgumentList "5","0","0"

        if ($psversion.Major -lt $min_psversion.Major) {    
            log_message -message "[ ] Unzip of Archive for Powershell Verson before 5.0 starting. Destination Path: $icinga_installPath\sbin\scripts\"
            $shell = New-Object -ComObject shell.application
            $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
            foreach ($item in $zip.items()) {
                $shell.Namespace("$icinga_installPath\sbin\scripts").copyhere($item,0x14)
            }
        } else {
            log_message -message "[ ] Unzip of Archive for Powershell Verson after 5.0 starting. Destination Path: $icinga_installPath\sbin\scripts\"
            Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$icinga_installPath\sbin\scripts" -Force
        }
        log_message -message "[+] Done."
     
    } else {
        log_message -message "[!] Abort of download and install of 'extra monitoring Plugins: Icinga2 Service is NOT installed"
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

    log_message -message "[i] Start nsclient++ customizing"

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
        log_message -message t "[!] ERROR: Installation-Path of NSClient not found!"

    } else {

        # Web-get the nsclient.ini
        $url_icinga2agent_nsclient_ini = "https://${neteye4endpoint}${url_icinga2agent_nsclient_ini}"
        $nsclient_dst_file = "${workpath}\nsclient.ini"

        log_message -message "[i] Going to download of nsclient.ini from $url_icinga2agent_nsclient_ini using credentials TO: $nsclient_dst_file"
        Invoke-WebRequest -Uri $url_icinga2agent_nsclient_ini -OutFile $nsclient_dst_file -Headers $headers

        # If download was successful replace existing .ini file
        if (Test-Path $nsclient_dst_file) {

            log_message -message "[+] Download of nsclient.ini successful."

            Copy-Item "${nsclient_installPath}\nsclient.ini" -Destination ${nsclient_installPath}\nsclient.ini.${date_execution}_bak    
            log_message -message "[i] Created copy of original nsclient.ini to ${nsclient_installPath}\nsclient.ini.${date_execution}_bak."
    
            Move-Item -Force -Path $nsclient_dst_file -Destination ${nsclient_installPath}\nsclient.ini
            log_message -message "[i] Moved new nsclient.ini to ${nsclient_installPath}\nsclient.ini."

            # Restart service of nsclient++ if currently running
            if (Get-Service -Name $nsclient_serviceName -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"} | Restart-Service){
                log_message -message "[+] Restarted service of NSClient++"
            } else {
                log_message -message "[!] Failure while restarting service of NSClient++. Is Service '$nsclient_serviceName' installed ?"
            }
        }
        log_message -message "[+] Done"
    }
}


#
# Section: Expand NSClient Plugins to NSClient\scripts
If (( $action_custom_nsclient -eq $TRUE ) -and ( $action_extra_plugins -eq $TRUE )) {

    log_message -message "[i] Install additional Monitoring Plugins into NSClient++ install path"

    if ($psversion.Major -lt $min_psversion.Major) {
        
        log_message -message "  -Powershell is below 5.0"
        $shell = New-Object -ComObject shell.application
        $zip = $shell.Namespace($icinga2_monitoring_plugins_dst_path)
        foreach ($item in $zip.items()) {
            $shell.Namespace("$nsclient_installPath\scripts").copyhere($item,0x14)
        }
    } else {
        log_message -message "  -Powershell is above 5.0 and Expand-Archive is supported"
        Expand-Archive $icinga2_monitoring_plugins_dst_path -DestinationPath "$nsclient_installPath\scripts" -Force
    }
    log_message -message "[+] Done."
}


#
# Section: Deployment of OCSAgent
if ( $action_install_OCS_agent -eq $TRUE ){

    log_message -message "[i] Going to deploy OCS agent ..."

    $ocsagent_dst_file = "${workpath}\OcsPackage.exe"
    If (Get-Service -Name "OCS Inventory Service" -ErrorAction SilentlyContinue) {
        log_message -message "[i] OCS Agent is already installed - nothing todo"
    
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

        log_message -message "[i] OCS has to be installed. Downloading OCSPackage from $url_ocsagent_path TO: $ocsagent_dst_file"
        Invoke-WebRequest -Uri $url_ocsagent_path -OutFile $ocsagent_dst_file -Headers $headers

        # If download was successful start installation
        If (Test-Path $ocsagent_dst_file) {

           log_message -message "Start OCS-Agent Installation"
           echo "[+] START OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append

           Start-Process -Wait -FilePath $ocsagent_dst_file 
           log_message -message "END OCS-Agent Installation"
           echo "[+] END OCS-Agent-Installation" | Out-File -FilePath "$log_file" -Append

        } else {
            echo "[!] Failure installing OCS Agent."
        }

    }
}


# temp directory clean up
log_message -message "[i] Final step: clean-up of temp-directory"
echo "clean temp-directory" | Out-File -FilePath "$log_file" -Append

If (( $action_install_OCS_agent -eq $TRUE ) -and (Test-Path $ocsagent_dst_file)) {
    log_message -message "Removing: $ocsagent_dst_file"
    Remove-Item $ocsagent_dst_file -Force
}

If (($action_extra_plugins -eq $TRUE ) -and (Test-Path $icinga2_monitoring_plugins_dst_path)) {
    log_message -message "Removing: $icinga2_monitoring_plugins_dst_path"
    Remove-Item $icinga2_monitoring_plugins_dst_path -Force
}

If ((![string]::IsNullOrWhiteSpace($icinga2agent_psm1_file)) -and ( $action_install_Icinga2_agent -eq $TRUE ) -and (Test-Path $icinga2agent_psm1_file)) {
    log_message -message "Removing: $icinga2agent_psm1_file"
    Remove-Item $icinga2agent_psm1_file -Force
}

If (($action_extra_plugins -eq $TRUE) -and (Test-Path "$workpath/Icinga2-*.msi")) {
    log_message -message "Removing: $workpath/Icinga2-*.msi"
    Remove-Item "$workpath/Icinga2-*.msi"
}

log_message -message "[i] All steps completed. Done. ;o)"
