###########################################################################################################################################################
#.Description
# This scripts provide the necessary Steps to validate and configure a SQL Server Instance for the SQLDMVMonitor Service. If the necessary 
# configurations are not present the script will set the permissions.
#
# Prerequisits:
#  - Scripts check if the SMO Assemblies are installed on the GAC. To install the SMO please download the SharedManagementObjects.msi from microsoft. 
#  - User runnning this scripts need SYSAdmin rights on the SQL Server Instance that will be configured (defined in the sqltrace.conf file)
#
#.Input Parameters:
#.Parameter -SQLTraceConfigFile  (Mandatory)
#  Valid Path to a SQL DMV Monitoring configuration file e.g. c:\tmp\sqltrace.conf
#  Please take into considerations that sql server disk must have at least 2 GB of free space for that extended event sessions. 
#  Please put Directory on Disk where no SQL DATA and Transaction Log IO will me made. 
#.Parameter -SQLExtEventDir  (Mandatory)
#  Valid Path where the SQL Extended Events are writen. The direcotry must exist on Computer of the SQL Server Instance, as sql service is writing the events.
#.Parameter -SQLTraceServiceaccount (Mandatory)
#  Windows Account name which will run the SQL DMV Monitor service. The script will give this account the necessary permissions.
#.Parameter -OnlyValidate
# Will execute the Script without making Configurations. It will only check if Configurations are already set. The Returned Object will contain the details!
#
# Output:
# The Output is a Hashtable. It describes if needed configurations are present or has been set. Each key returns the status as boolean. You can query the result like a Object.
# Validation/Configuration is valid if $_result.SQLInstancePrepared true. 
# If it is not true you can query the other properties (configurations) for details which Configurations is not set.
# The Details of the Configuration Checks can be get using following attributes from result:
#   $_result.SQLStatusDetails 
#   $_result.AXStatusDetails
#
# In case the $_result.hasExceptions is true you have to check the $_result.ExceptionMessage. It contains a detailed message regarding the error.
# 
# Structure of the Result:
#
#            SQLInstancePrepared:                True/False
#            AXStatus:                           True/False
#            AXStatusDetails.
#               AXBusinessDBExist                True/False
#               AXBusinessDBPermissionsExist     True/False
#            SQLStatus                           True/False
#            SQLStatusDetails.               
#               SQLMajorVersionSupported         True/False
#               SQLTraceAccountExist             True/False
#               SQLBlockingThresholdSetup        True/False
#               SQLTraceAccountPermissionsExist: True/False
#               SQLExtendedEventDirExists        True/False
#               SQLExtendedEventChannelsSetup    True/False
#            hasExceptions                       True/False
#            ExceptionMessage                    Text (if hasExcpetions=true)
#
# Example:
#  $_result=.\Prepair4SQLDMVMonitor.ps1 -SQLTraceConfigFile C:\tmp\sqltraceerror.conf -SQLExtEventDir c:\temp -SQLTraceServiceaccount 'domain\windowsaccount' -OnlyValidate
#  $_result.SQLInstancePrepared
#  # OUTPUT will be e.g:
#        False 
#  $_result.hasExceptions
#  # OUTPUT will be e.g:
#        False
#
#  $_result.AXStatusDetails
#  OUTPUT will be e.g.:
#        Name                           Value                                                                                                                                                                                                                          
#        ----                           -----                                                                                                                                                                                                                          
#        AXBusinessDBExist              True                                                                                                                                                                                                                           
#        AXBusinessDBPermissionsExist   True  
#
#  $_result.SQLStatusDetails
#  OUTPUT will be e.g.:
#        Name                           Value                                                                                                                                                                                                                          
#        ----                           -----                                                                                                                                                                                                                          
#        SQLTraceAccountExist           True      
#        SQLMajorVersionSupported       True                                                                                                                                                                                                                     
#        SQLBlockingThresholdSetup      True                                                                                                                                                                                                                           
#        SQLTraceAccountPermissionsE... True                                                                                                                                                                                                                           
#        SQLExtendedEventDirExists      True                                                                                                                                                                                                                           
#        SQLExtendedEventChannelsSetup  False                                                                                                                                                                                                                          
#
#
###########################################################################################################################################################
#region Parameters

[OutputType([System.Collections.Hashtable])]
param (
    [Parameter(Mandatory)]
    [string] $SQLTraceConfigFile,
    [Parameter(Mandatory)]
    [string] $SQLExtEventDir,
    [Parameter(Mandatory)]
    [string] $SQLTraceServiceaccount,
    [switch] $OnlyValidate,
    [int] $SQLXEFilterDuration      = 100000,
    [int] $SQLNumberOfFiles         = 5,
    [int] $SQLSizeOfFile            = 100,
    [int] $SQLBlockedThreshold      = 5
)


function Out-Msg 
{
param (
       [ValidateSet("ERROR", "INFO", "SUCCESS","WARNING")]
       [string]$Type,
       [string]$Message
      )
#region Parameters

    $OriginalForegroundColor = $host.ui.RawUI.ForegroundColor
    $OriginalBackgroundColor = $host.ui.RawUI.BackgroundColor


    switch ($Type) 
                { 
                  ERROR   {
                           $host.ui.RawUI.ForegroundColor = “Red” 
                           $host.ui.RawUI.BackgroundColor = “Black”
                           Write-Error -ErrorAction SilentlyContinue $Message
                           Write-Host “$(currentDateTime) ERROR: $Message” 
                          }

                  WARNING {
                           $host.ui.RawUI.ForegroundColor = “Yellow” 
                           $host.ui.RawUI.BackgroundColor = “Black”
                           Write-Host “$(currentDateTime) WARNING: $Message” 
                          }                         

                  SUCCESS {
                           
                           $host.ui.RawUI.ForegroundColor = “Green” 
                           $host.ui.RawUI.BackgroundColor = “Black”
                           Write-Host “$(currentDateTime) SUCCESS: $Message”
                          }

                  INFO    {
                           $host.ui.RawUI.ForegroundColor = “White” 
                           $host.ui.RawUI.BackgroundColor = “Black”
                           Write-Host “$(currentDateTime) INFO: $Message” 
                          } 
                }
    
     $host.ui.RawUI.ForegroundColor = $OriginalForegroundColor
     $host.ui.RawUI.BackgroundColor = $OriginalBackgroundColor

}

function currentDateTime 
{
          Get-Date -format 'u'
}


function ConvertFrom-SQLTraceConfigFile {
 
<#
.Synopsis
Convert an sqltrace conf file to an object
.Description
It is assumed that your  file follows a typical layout like this:

# This is a sample
[General]
Action = Start 
Directory = c:\work
ID = 123ABC
 
 #this is another comment
[Application]
Name = foo.exe
Version = 1.0
 
[User]
Name = Jeff
Company = Globomantics
 
.Parameter Path
The path to the SQL Trace Config file.
.Example
PS C:\> $sample = ConvertFrom-SQLTraceConfigFile  c:\scripts\sample.conf
PS C:\> $sample
 
#>
 
[cmdletbinding()]
Param(
[Parameter(Position=0,Mandatory,HelpMessage="Enter the path to an INI file",
ValueFromPipeline, ValueFromPipelineByPropertyName)]
[Alias("fullname","pspath")]
[ValidateScript({
if (Test-Path $_) {
   $True
}
else {
  Throw "Cannot validate path $_"
}
})]     
[string]$Path
)
 
 
Begin {
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
} #begin
 
Process {
    Write-Verbose "Getting content from $(Resolve-Path $path)"
    #strip out comments that start with ; and blank lines
    $all = Get-content -Path $path | Where {$_ -notmatch "^(\s+)?#|^\s*$"} |Where {$_ -notmatch "^(\s+)?;|^\s*$"}
 
    $obj = New-Object -TypeName PSObject -Property @{}
    $hash = [ordered]@{}
 
    foreach ($line in $all) {
 
        [string] $orgLine=$line
        Write-Verbose "Processing $line"
        $line=$line.Split('#')[0].Trim()
        if ($line -match "^\[.*\]$" -AND $hash.count -gt 0) {
            #has a hash count and is the next setting
            #add the section as a property
            Write-Verbose "Creating section $section"
            Write-Verbose ([pscustomobject]$hash | out-string)
            $obj | Add-Member -MemberType Noteproperty -Name $Section -Value $([pscustomobject]$Hash) -Force
            #reset hash
            Write-Verbose "Resetting hashtable"
            $hash=[ordered]@{}
            #define the next section
            $section = $line -replace "\[|\]",""
            Write-Verbose "Next section $section"
        }
        elseif ($line -match "^\[.*\]$") {
            #Get section name. This will only run for the first section heading
            $section = $line -replace "\[|\]",""
            Write-Verbose "New section $section"
        }
        elseif ($line -match "=") {
            [PSObject]$keyobj =Parse-SQLTraceConfigFileKeyValue -KeyValuePair $line
            $hash.add($keyobj.Name,$keyobj.Value)
        }
        else {
            #this should probably never happen
            Throw  "Unexpected line $orgLine"
        }
 
    } #foreach
 
    #get last section
    If ($hash.count -gt 0) {
      Write-Verbose "Creating final section $section"
      Write-Verbose ([pscustomobject]$hash | Out-String)
     #add the section as a property
     $obj | Add-Member -MemberType Noteproperty -Name $Section -Value $([pscustomobject]$Hash) -Force
    }
 
    #write the result to the pipeline
    $obj
} #process
} #end function

function Parse-SQLTraceConfigFileKeyValue {

[cmdletbinding()]
[OutputType([PSObject])]
Param(
[Parameter(Mandatory)]
[string]$KeyValuePair
)
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [string] $line=$KeyValuePair
    #parse data
    $data= $line.split("=",2).trim()
    [string] $value=$data[1].Trim()
    [string] $keyname=$data[0].Trim()
    [string] $dtype='value'
    if ($value.StartsWith('"'))
    {
        $dtype='string'
    }elseif ($value.StartsWith('{')){
        $dtype='object'
    }

    [PSObject]$keyobj = New-Object -TypeName PSObject -Property @{}
    $keyobj | Add-Member -MemberType Noteproperty -Name Type -Value $dtype -Force
    $keyobj | Add-Member -MemberType Noteproperty -Name Name -Value $keyname -Force

    if($dtype -eq 'string')
    {
        $value=$value.Trim('"')
        while ($value.Contains('\\'))
        {
            $value=$value.Replace('\\','\')
        }
        $keyobj | Add-Member -MemberType Noteproperty -Name Value -Value $value -Force

    }
    if($dtype -eq 'object')
    {
        $value=$value.TrimStart('{')
        $value=$value.TrimEnd('}')
        [System.Collections.Hashtable] $pairs=Parse-SQLTraceInlineTable -keyName $keyname -KeyValue $value
        $keyobj | Add-Member -MemberType Noteproperty -Name Value -Value $([pscustomobject]$pairs) -Force
    }

    return $keyobj
}

function Parse-SQLTraceInlineTable {

[cmdletbinding()]
[OutputType([System.Collections.Hashtable])]
Param(
[Parameter(Mandatory)]
[string]$keyName,
[Parameter(Mandatory)]
[string]$KeyValue
)
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [System.Collections.Hashtable]$hash = @{}
    [string] $value=$KeyValue
    [string[]] $pairs=$value.Split(',')
    [PSObject] $keyobject=$null
    foreach($pair in $pairs)
    {
        $keyobject=Parse-SQLTraceConfigFileKeyValue -KeyValuePair $pair
        $hash.add($keyobject.Name,$keyobject.Value)
    }

    return $hash
}

function Create-DBAEventUsingScript
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlInstance")]
        [object]$SqlServer,
        [Parameter(Mandatory = $true)]
        [string]$Script,
        [System.Management.Automation.PSCredential]$SqlCredential
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
    $sql = "EXEC master.dbo.xp_fileexist '$path'"
    $fileexist = $server.ConnectionContext.ExecuteWithResults($sql)

    if ($fileexist.tables.rows[1] -eq $true)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Test-SqlPath
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlInstance")]
        [object]$SqlServer,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [System.Management.Automation.PSCredential]$SqlCredential
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
    $sql = "EXEC master.dbo.xp_fileexist '$path'"
    $fileexist = $server.ConnectionContext.ExecuteWithResults($sql)

    if ($fileexist.tables.rows[1] -eq $true)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Get-BlockedProcessThreshold
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlInstance")]
        [object]$SqlServer,
        [System.Management.Automation.PSCredential]$SqlCredential
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
    $sql = 'SELECT value FROM sys.configurations where configuration_id=1569 --blocked process threshold (s)'
    $Configds = $server.ConnectionContext.ExecuteWithResults($sql)

    return $Configds.tables.rows[0]
}

function Connect-SqlServer
{
<#
.SYNOPSIS
Internal function that creates SMO server object. Input can be text or SMO.Server.
#>    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$SqlServer,
        [System.Management.Automation.PSCredential]$SqlCredential,
        [switch]$ParameterConnection,
        [switch]$RegularUser
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    
    if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server])
    {
        
        if ($ParameterConnection)
        {
            $paramserver = New-Object Microsoft.SqlServer.Management.Smo.Server
            $paramserver.ConnectionContext.ConnectTimeout = 2
            $paramserver.ConnectionContext.ApplicationName = "SQL Tracing - Validation/Preparation Setup"
            $paramserver.ConnectionContext.ConnectionString = $SqlServer.ConnectionContext.ConnectionString
            
            if ($SqlCredential.username -ne $null)
            {
                $username = ($SqlCredential.username).TrimStart("\")
                
                if ($username -like "*\*")
                {
                    $username = $username.Split("\")[1]
                    $authtype = "Windows Authentication with Credential"
                    $server.ConnectionContext.LoginSecure = $true
                    $server.ConnectionContext.ConnectAsUser = $true
                    $server.ConnectionContext.ConnectAsUserName = $username
                    $server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
                }
                else
                {
                    $authtype = "SQL Authentication"
                    $server.ConnectionContext.LoginSecure = $false
                    $server.ConnectionContext.set_Login($username)
                    $server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
                }
            }
            
            $paramserver.ConnectionContext.Connect()
            return $paramserver
        }
        
        if ($SqlServer.ConnectionContext.IsOpen -eq $false)
        {
            $SqlServer.ConnectionContext.Connect()
        }
        return $SqlServer
    }
    
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlServer
    $server.ConnectionContext.ApplicationName = "SQL Tracing - Validation/Preparation Setup"
    
    try
    {
        if ($SqlCredential.username -ne $null)
        {
            $username = ($SqlCredential.username).TrimStart("\")
            
            if ($username -like "*\*")
            {
                $username = $username.Split("\")[1]
                $authtype = "Windows Authentication with Credential"
                $server.ConnectionContext.LoginSecure = $true
                $server.ConnectionContext.ConnectAsUser = $true
                $server.ConnectionContext.ConnectAsUserName = $username
                $server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
            }
            else
            {
                $authtype = "SQL Authentication"
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.set_Login($username)
                $server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
            }
        }
    }
    catch { }
    
    try
    {
        if ($ParameterConnection)
        {
            $server.ConnectionContext.ConnectTimeout = 10
        }
        else
        {
            $server.ConnectionContext.ConnectTimeout = 11
        }
        
        $server.ConnectionContext.Connect()
    }
    catch
    {
        $message = $_.Exception.InnerException.InnerException
        $message = $message.ToString()
        $message = ($message -Split '-->')[0]
        $message = ($message -Split 'at System.Data.SqlClient')[0]
        $message = ($message -Split 'at System.Data.ProviderBase')[0]
        throw "Can't connect to $sqlserver`: $message "
    }
    
    if ($RegularUser -eq $false)
    {
        if ($server.ConnectionContext.FixedServerRoles -notmatch "SysAdmin")
        {
            throw "Not a sysadmin on $SqlServer. Quitting."
        }
    }
    
    if ($ParameterConnection -eq $false)
    {
        if ($server.VersionMajor -eq 8)
        {
            # 2000
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Version')
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'CreateDate', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'Name', 'Sid', 'WindowsLoginAccessType')
        }
        
        
        elseif ($server.VersionMajor -eq 9 -or $server.VersionMajor -eq 10)
        {
            # 2005 and 2008
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
        }
        
        else
        {
            # 2012 and above
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'ActiveConnections', 'AvailabilityDatabaseSynchronizationState', 'AvailabilityGroupName', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'ContainmentType', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordHashAlgorithm', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
        }
    }
    
    return $server
}

function Get-DbaXESession {
    [CmdletBinding()]
    [OutputType([Microsoft.SqlServer.Management.XEvent.Session])]
    param (
        [parameter(Mandatory)]
        [object]$SqlServer,
        [parameter(Mandatory)]
        [string]$XESessionname,
        [System.Management.Automation.PSCredential]$SqlCredential
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
    $SqlConn = $server.ConnectionContext.SqlConnectionObject
    $SqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection $SqlConn
    $XEStore = New-Object  Microsoft.SqlServer.Management.XEvent.XEStore $SqlStoreConnection

    [Microsoft.SqlServer.Management.XEvent.Session] $xSes=$null
    $xSes=$XEStore.Sessions[$XESessionname]

    return $xSes
}

function get-SQLXEDURATIONScript 
{
    [CmdletBinding()]
    [OutputType([String])]
    param ()
    [string] $scriptSQLXEDURATION = 'CREATE EVENT SESSION <SessionName> ON SERVER 
    ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
        ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.database_name,sqlserver.nt_username,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.transaction_sequence,sqlserver.username)
        WHERE ([duration]>=(<duration>) AND [package0].[not_equal_uint64]([sqlserver].[session_id],(0)))),
    ADD EVENT sqlserver.sp_statement_completed(SET collect_object_name=(1),collect_statement=(1)
        ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.database_name,sqlserver.nt_username,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.transaction_sequence,sqlserver.username)
        WHERE ([duration]>=(<duration>) AND [package0].[not_equal_uint64]([sqlserver].[session_id],(0)))),
    ADD EVENT sqlserver.sql_statement_completed(SET collect_statement=(1)
        ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.database_name,sqlserver.nt_username,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.transaction_sequence,sqlserver.username)
        WHERE ([duration]>=(<duration>) AND [package0].[not_equal_uint64]([sqlserver].[session_id],(0))))
    ADD TARGET package0.event_file(SET filename = ''<SQLExtSessionFileName>'',max_file_size=(<SQLSizeOfFile>),max_rollover_files=(<SQLNumberOfFiles>))
    WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)'

    return $scriptSQLXEDURATION
}

function get-SQLXECURSORSScript
{
    [CmdletBinding()]
    [OutputType([String])]
    param ()
    [string] $scriptSQLXECURSORS = 'CREATE EVENT SESSION <SessionName> ON SERVER 
    ADD EVENT sqlserver.cursor_close(
        ACTION(sqlserver.session_id)),
    ADD EVENT sqlserver.cursor_execute(
        ACTION(sqlserver.context_info,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id)),
    ADD EVENT sqlserver.cursor_open(
        ACTION(sqlserver.context_info,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id)),
    ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
        ACTION(sqlserver.client_hostname,sqlserver.context_info,sqlserver.nt_username,sqlserver.session_id,sqlserver.username)
        WHERE ([sqlserver].[equal_i_sql_unicode_string]([object_name],N''sp_cursorfetch'') AND [package0].[greater_than_uint64]([duration],(<duration>))))
    ADD TARGET package0.event_file(SET filename=''<SQLExtSessionFileName>'',max_file_size=(<SQLSizeOfFile>),max_rollover_files=(<SQLNumberOfFiles>))
    WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)'

    return $scriptSQLXECURSORS
}



function get-SQLXEBLOCKINGScript
{
    [CmdletBinding()]
    [OutputType([String])]
    param ()
    [string] $scriptSQLXEBLOCKING = 'CREATE EVENT SESSION <SessionName> ON SERVER 
    ADD EVENT sqlserver.blocked_process_report(
    ACTION(package0.collect_system_time,sqlserver.client_hostname,sqlserver.context_info,sqlserver.server_instance_name,sqlserver.session_id)),
    ADD EVENT sqlserver.lock_escalation(SET collect_statement=(1)
    ACTION(package0.collect_system_time,sqlserver.client_hostname,sqlserver.context_info,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.server_instance_name,sqlserver.session_id,sqlserver.username)),
    ADD EVENT sqlserver.xml_deadlock_report(
    ACTION(package0.collect_system_time,sqlserver.client_hostname,sqlserver.context_info,sqlserver.server_instance_name,sqlserver.session_id))
    ADD TARGET package0.event_file(SET filename=''<SQLExtSessionFileName>'',max_file_size=(<SQLSizeOfFile>),max_rollover_files=(<SQLNumberOfFiles>))
    WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)'

    return $scriptSQLXEBLOCKING
}

function Create-dbaXESession
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlInstance")]
        [object]$SqlServer,
        [Parameter(Mandatory = $true)]
        [string]$Script,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $parameters,
        [System.Management.Automation.PSCredential]$SqlCredential

    )
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    [bool]$result=$true
    [string] $tmpScriptSQLXEDURATION=$Script

    foreach ($p in $parameters.GetEnumerator())
    {
        $tmpScriptSQLXEDURATION= $tmpScriptSQLXEDURATION -replace "$($p.key)","$($p.value)"
    }
    $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
    $sql = $tmpScriptSQLXEDURATION
    try
    {
        $fileexist = $server.ConnectionContext.ExecuteNonQuery($sql)
    }
    catch
    {
        $ErrorMessage = $_.Exception
        $result= $false
    }

    return $result
}

function Configure-dbaXESession
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlInstance")]
        [object]$SqlServer,
        [parameter(Mandatory)]
        [string]$XESessionname,
        [parameter(Mandatory)]
        [string]$XEFileDirectory,
        [Parameter(Mandatory = $true)]
        [string]$Script,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $parameters,
        [System.Management.Automation.PSCredential]$SqlCredential
    )
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    [bool]$result=$true

    [Microsoft.SqlServer.Management.XEvent.Session] $XE=Get-DbaXESession -SqlServer $SqlServer -XESessionname $XESessionname
    if ($XE)
    {
        if ($XE.IsRunning)
        {
            $XE.Stop()
        }
        $XE.Drop()
    }

    [System.Collections.Hashtable]$parametersXE=$parameters + @{
    "<SQLExtSessionFileName>"="$($XEFileDirectory)\$($XESessionname).xel"
    "<SessionName>"="$($XESessionname)"
    }

    if (Create-dbaXESession -SqlServer $SqlServer -Script $Script -parameters $parametersXE)
    {
        $XE=Get-DbaXESession -SqlServer $SQLServerInstance -XESessionname $XESessionname
        if (-not ($XE.IsRunning))
        {
            $XE.Start()
        }
    }

    return $result
}

function Get-AXTableNames
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
    )
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    [string[]]$axtablenames =@(
    'BATCHJOB ',
    'BATCH',
    'BATCHCONSTRAINTS',
    'BATCHJOBHISTORY',
    'BATCHHISTORY',
    'BATCHCONSTRAINTSHISTORY',
    'BATCHCONSTRAINTS',
    'BATCHSERVERGROUP',
    'BATCHGROUP',
    'BATCHSERVERCONFIG',
    'SYSSERVERCONFIG'
    )

    return $axtablenames
}

function Init-Assemblies-SMO
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    $resSMO    = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    $resXevent = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.XEvent")

    [bool] $isloaded= (($resSMO -ne $null) -and ($resXevent -ne $null))
    If (-not $isloaded)
    {
        throw  "Could not load required assemblies 'Microsoft.SqlServer.SMO' and 'Microsoft.SqlServer.Management.XEvent'.`nPlease verify that SQL Server Management Objects (SMO) packages is installed!!!! "
    }
    return   $isloaded
}

function Read-SQLTraceConfiguratinFile
{

    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SQLTraceConfigFile
    )
    
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [PSObject]$SQLTraceConfig= ConvertFrom-SQLTraceConfigFile $SQLTraceConfigFile 
    [System.Collections.Hashtable]$SQLTraceCfg=$null

    if ($SQLTraceConfig)
    {
        #params taken from SQLTraceConfigFile
        [string] $SQLServer                = $SQLTraceConfig.main.dataSource #'pbzaxsql01'
        [string] $AXBusinessDBname         = $SQLTraceConfig.'dmv.DX.AX2012'.databaseName #'AX6_CFA_DEV_Build'
        [string] $AXBusinessDS             = $SQLTraceConfig.'dmv.DX.AX2012'.dataSource 
        [string] $SQLXEDurationSessionName = $SQLTraceConfig.main.queriesProbe #'WPPERF_SQL_DURATION'
        [string] $SQLXECursorsSessionName  = $SQLTraceConfig.main.fetchesProbe #'WPPERF_SQL_CURSORS'
        [string] $SQLXEBlockingSessionName = $SQLTraceConfig.main.blockingsProbe #'WPPERF_BLOCKING_DATA'

        if ($AXBusinessDBname -and -not $AXBusinessDS)
        {
            $AXBusinessDS=$SQLServer
        }

        if ($SQLServer -and  $SQLXEDurationSessionName -and $SQLXECursorsSessionName -and $SQLXEBlockingSessionName)
        {
            [System.Collections.Hashtable]$SQLTraceCfg=@{
                "SQLServer"= $SQLServer
                "SQLXEDurationSessionName"=$SQLXEDurationSessionName
                "SQLXECursorsSessionName"=$SQLXECursorsSessionName
                "SQLXEBlockingSessionName"=$SQLXEBlockingSessionName
                "AXBusinessDS"=$AXBusinessDS
                "AXBusinessDBname"=$AXBusinessDBname
            }
        }
        else
        {
            throw ("SQL Trace Config file $SQLTraceConfigFile is not valid !!")
        }
    }

    return $SQLTraceCfg
}


function Init-SQLServerConnection
{
    [CmdletBinding()]
    [OutputType([Object])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SQLServer
    )
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    [Object] $SQLServerInstance = $null;
    $SQLServerInstance          = Connect-SqlServer -SqlServer $SQLServer
    return $SQLServerInstance
}


function Validate-SQLEXEventDir
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]     
        [string]$SQLExtEventDir   
    )
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    [bool] $existDir=$true
    if (-not (Test-SqlPath -SqlServer $SQLServerInstance -Path $SQLExtEventDir))
    {
        $existDir=$false
    }
    return $existDir
}

function Validate-SQLEXEventsChannels
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]     
        [System.Collections.Hashtable]$SQLTraceCfg
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [bool] $existXEDuration=$false
    [bool] $existXECursors =$false
    [bool] $existXEBlocking=$false

    $XEDuration = Get-DbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXEDurationSessionName
    $existXEDuration= ($XEDuration -and $XEDuration -ne $null)
    $XECursors  = Get-DbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXECursorsSessionName
    $existXECursors= ($XECursors -and $XECursors -ne $null)
    $XEBlocking = Get-DbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXEBlockingSessionName
    $existXEBlocking= ($XEBlocking -and $XEBlocking -ne $null)
    
    return $existXEDuration -and $existXECursors -and $existXEBlocking
}


function Validate-SQLBlockingTreshold
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [int] $SQLBlockedThreshold
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [bool] $isValid=$false
    [int] $blockedThreshold = $SQLServerInstance.Configuration.BlockedProcessThreshold.RunValue
    if (($blockedThreshold) -eq $SQLBlockedThreshold)
    {
        $isValid=$true
    }
    else
    {
        $isValid=$true
    }
    return $isValid
}

function Validate-Permissions
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [string] $SQLAccount
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [bool] $permGrant=$true

    [String[]] $checkPermissions=@(
    "SELECT HAS_PERMS_BY_NAME(null, null, 'VIEW SERVER STATE')",  
    "SELECT HAS_PERMS_BY_NAME(null, null, 'VIEW ANY DEFINITION')"
    )

    foreach ($perm in $checkPermissions)
    {
        $sqllogin   = $SQLAccount
        $sqlcmd     = "EXECUTE AS LOGIN ='$sqllogin' $perm  GO REVERT"
        [int] $result=$null
        $result=$SQLServerInstance.ConnectionContext.ExecuteScalar($sqlcmd) -eq 1
    
        $permGrant= $permGrant -and ($result -eq 1)
    }

    return $permGrant

}

function Validate-Permissions-AXBusinessDB
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [string] $SQLAccount,
        [Parameter(Mandatory = $true)]
        [string] $AXBusinessDBname
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [bool] $permGrant=$false

    [String[]] $checkPermissions=@()

    if($AXBusinessDBname)
    {
        #setup Permissions in AX Business DB
        [Microsoft.SqlServer.Management.Smo.Database]$AXBusinessDB=$SQLServerInstance.Databases[$SQLTraceCfg.AXBusinessDBname]

        if ($AXBusinessDB)
        {
            foreach ($axtablename in Get-AXTableNames)
            {
                $checkPermissions=$checkPermissions+@(
                "SELECT HAS_PERMS_BY_NAME(N'$AXBusinessDBname.dbo.$axtablename', N'OBJECT', N'SELECT')"
                )
            }
        }

        $permGrant=$true
        foreach ($perm in $checkPermissions)
        {
            $sqllogin   = $SQLAccount
            $sqlcmd     = "EXECUTE AS LOGIN ='$sqllogin' $perm  GO REVERT"
            [int] $result=$null
            $result=$SQLServerInstance.ConnectionContext.ExecuteScalar($sqlcmd) -eq 1
    
            $permGrant= $permGrant -and ($result -eq 1)
        }

    }
    return $permGrant
}
##################################################################################
###                         VALIDATE-Prerequistes are SETUP
################################################################################
function Validate-SQLInstance
{
    [CmdletBinding()]
    
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$SQLTraceCfg,
        [Parameter(Mandatory = $true)]
        [string] $SQLExtEventDir,
        [Parameter(Mandatory)]
        [string] $SQLTraceServiceaccount,
        [Parameter(Mandatory)]
        [int] $SQLBlockedThreshold,
        [Parameter(Mandatory)]
        [int] $SQLMajorVersionMinimum
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [System.Collections.Hashtable] $status=@{
        SQLMajorVersionSupported=$false
        SQLBlockingThresholdSetup=$false
        SQLExtendedEventDirExists=$false
        SQLExtendedEventChannelsSetup=$false
        SQLTraceAccountExist=$false
        SQLTraceAccountPermissionsExist=$false
    }

    if ($SQLServerInstance.VersionMajor -ge $SQLMajorVersionMinimum)
    {
        $status.SQLMajorVersionSupported=$true
    }

    $status.SQLBlockingThresholdSetup=Validate-SQLBlockingTreshold -SQLServerInstance $SQLServerInstance -SQLBlockedThreshold $SQLBlockedThreshold
    $status.SQLExtendedEventDirExists=Validate-SQLEXEventDir -SQLServerInstance $SQLServerInstance -SQLExtEventDir $SQLExtEventDir

    if ($SQLTraceCfg)
    {
        $status.SQLExtendedEventChannelsSetup=Validate-SQLEXEventsChannels -SQLServerInstance $SQLServerInstance -SQLTraceCfg $SQLTraceCfg
    }

    [Microsoft.SqlServer.Management.Smo.Login] $SQLTraceLogin=$null
    $SQLTraceLogin=$SQLServerInstance.Logins[$SQLTraceServiceaccount]
    if($SQLTraceLogin)
    {
        $status.SQLTraceAccountExist= $true
    }

    if ($status.SQLTraceAccountExist)
    {
        $status.SQLTraceAccountPermissionsExist=Validate-Permissions -SQLServerInstance $SQLServerInstance -SQLAccount $SQLTraceLogin.Name 
    }


    return $status
}

function Validate-SQLAXBusinessDB
{
    [CmdletBinding()]
    
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$SQLTraceCfg,
        [Parameter(Mandatory)]
        [string] $SQLTraceServiceaccount,
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $SQLStatus

    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    [System.Collections.Hashtable] $status=@{
        AXBusinessDBExist=$false
        AXBusinessDBPermissionsExist=$false
    }

    [Microsoft.SqlServer.Management.Smo.Database]$AXBusinessDB=$SQLServerInstance.Databases[$SQLTraceCfg.AXBusinessDBname]


    if($AXBusinessDB)
    {
        $status.AXBusinessDBExist=$true
        if ($SQLStatus.SQLTraceAccountExist)
        {
            $status.AXBusinessDBPermissionsExist=Validate-Permissions-AXBusinessDB -SQLServerInstance $SQLServerInstance -SQLAccount $SQLTraceServiceaccount -AXBusinessDBname  $SQLTraceCfg.AXBusinessDBname 
        }
    }

    return $status
}

###################################################################################
###                             CONFIGURE Prerequisites
###################################################################################
function Configure-SQLInstance4DMVTracing
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$SQLTraceCfg,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $SQLStatus,
        [Parameter(Mandatory)]
        [string] $SQLTraceServiceaccount,
        [Parameter(Mandatory)]
        [int] $SQLBlockedThreshold,
        [Parameter(Mandatory)]
        [int] $SQLXEFilterDuration,
        [Parameter(Mandatory)]
        [int] $SQLNumberOfFiles,
        [Parameter(Mandatory)]
        [int] $SQLSizeOfFile

    )
    
    Write-Verbose "Starting $($MyInvocation.Mycommand)"  
    

    if (-not $SQLStatus.SQLMajorVersionSupported)
    {
        throw "SQL Server Instance is not supported for SQL DMV Monitor!!"
    }

    if ($SQLStatus.SQLExtendedEventDirExists)
    {
        #Configure SQL XE Event Channels
        #internal parameters
        [string] $scriptSQLXEDURATION = get-SQLXEDURATIONScript
        [string] $scriptSQLXECURSORS  = get-SQLXECURSORSScript
        [string] $scriptSQLXEBLOCKING = get-SQLXEBLOCKINGScript
        [System.Collections.Hashtable]$parameters=@{
            "<duration>"= "$SQLXEFilterDuration";
            "<SQLSizeOfFile>"="$($SQLSizeOfFile)"
            "<SQLNumberOfFiles>"="$($SQLNumberOfFiles)"
        }

        [bool] $isXEDuration=Configure-dbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXEDurationSessionName  -XEFileDirectory $SQLExtEventDir -Script $scriptSQLXEDURATION -parameters $parameters
        [bool] $isXECursors =Configure-dbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXECursorsSessionName  -XEFileDirectory $SQLExtEventDir -Script $scriptSQLXECURSORS -parameters $parameters
        [bool] $isXEBlocking=Configure-dbaXESession -SqlServer $SQLServerInstance -XESessionname $SQLTraceCfg.SQLXEBlockingSessionName  -XEFileDirectory $SQLExtEventDir -Script $scriptSQLXEBLOCKING -parameters $parameters
    }
    else
    {
        Throw "Extended Events has not been created! Verify that SQL Extended Event Directory $SQLExtEventDir does not exits on $($SQLTraceCfg.SQLServer) and SQL Service has permissions to read/write to it!!!"
    }


    if (-not $SQLStatus.SQLBlockingThresholdSetup)
    {
        Write-Host "Setting Blocked Threshold value to $SQLBlockedThreshold !!"
        $SQLServerInstance.Configuration.BlockedProcessThreshold.ConfigValue=$SQLBlockedThreshold
        Write-Host "Apply new Threshold...."
        $SQLServerInstance.Configuration.Alter()
    }


    if(-not $SQLStatus.SQLTraceAccountExist)
    {
        $SQLTraceLogin = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $SQLServerInstance, $SQLTraceServiceaccount
        $SQLTraceLogin.LoginType  = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUser
        $SQLTraceLogin.Create() 
    }
	else
	{
	    $SQLTraceLogin=$SQLServerInstance.Logins[$SQLTraceServiceaccount]
	}

    if ( -not $SQLStatus.SQLTraceAccountPermissionsExist)
    {
        #set sql permission required by sqltraceserviceaccount view server state and  view any definition 
        $permissionset = New-Object -TypeName  Microsoft.SqlServer.Management.Smo.ServerPermissionSet
        $permissionset = $permissionset.Add([Microsoft.SqlServer.Management.Smo.ServerPermission]::ViewServerState) 
        $permissionset = $permissionset.Add([Microsoft.SqlServer.Management.Smo.ServerPermission]::ViewAnyDefinition) 
        $SQLServerInstance.Grant($permissionset, $SQLTraceLogin.Name)
    }

    return @{}
}

function Configure-AXBusinessDB4DMVTracing
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$SQLServerInstance,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$SQLTraceCfg,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $AXStatus,
        [Parameter(Mandatory)]
        [string] $SQLTraceServiceaccount,
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $SQLStatus
    )

    Write-Verbose "Starting $($MyInvocation.Mycommand)"  

    #setup Permissions in AX Business DB
    [Microsoft.SqlServer.Management.Smo.Database]$AXBusinessDB=$SQLServerInstance.Databases[$SQLTraceCfg.AXBusinessDBname]
    if($AXBusinessDB -and $SQLStatus.SQLTraceAccountExist)
    {
        [Microsoft.SqlServer.Management.Smo.User] $dbTraceUser=$AXBusinessDB.users[$SQLTraceServiceaccount]
        if (-not $dbTraceUser)
        {
            $dbTraceUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.User -ArgumentList $AXBusinessDB,$SQLTraceServiceaccount
            $dbTraceUser.Login = $SQLTraceServiceaccount
            $dbTraceUser.create()
        }

        if(-not $AXStatus.AXBusinessDBPermissionsExist)
        {
            $AXBusinessDB.DefaultSchema='dbo'
            [Microsoft.SqlServer.Management.Smo.ObjectPermissionSet] $dbUserPermset = New-Object Microsoft.SqlServer.Management.Smo.ObjectPermissionSet
            $dbUserPermset=$dbUserPermset.Add([Microsoft.SqlServer.Management.Smo.ObjectPermission]::Select)

            foreach ($axtablename in Get-AXTableNames)
            {
                [Microsoft.SqlServer.Management.Smo.Table] $axTable = $AXBusinessDB.Tables[$axtablename]

                if ($axTable)
                {
                    $axTable.Grant($dbUserPermset,$dbTraceUser.Name)
                }
            }
        }
    }
    return @{}
}


###################################################################################
###                             MAIN
###################################################################################

    [bool] $endedWithExceptions=$false

    try
    {
        [bool] $isInit=Init-Assemblies-SMO

        [System.Collections.Hashtable]$SQLTraceCfg=Read-SQLTraceConfiguratinFile -SQLTraceConfigFile $SQLTraceConfigFile

        [Object] $SQLServerInstance = Init-SQLServerConnection -SqlServer $SQLTraceCfg.SQLServer;
        
        
        
        <# SQL Status Attributes:
                SQLMajorVersionSupported
                SQLBlockingThresholdSetup
                SQLExtendedEventDirExists
                SQLExtendedEventChannelsSetup
                SQLTraceAccountExist
                SQLTraceAccountPermissionsExist
            }
        #>
        [System.Collections.Hashtable]$SQLStatus = Validate-SQLInstance    -SQLServerInstance $SQLServerInstance -SQLTraceCfg $SQLTraceCfg -SQLExtEventDir $SQLExtEventDir -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLBlockedThreshold $SQLBlockedThreshold -SQLMajorVersionMinimum 11


        #validate SQLStatus with output

        if (-not $SQLStatus.SQLMajorVersionSupported)
        {
            Out-Msg -Type WARNING "SQL Server Instance is not supported for SQL DMV Monitor!! SQL Server Version must be 2012 or higher !!"
        }

        if (-not $SQLStatus.SQLExtendedEventDirExists)
        {
            Out-Msg -Type WARNING "SQL Extended Event Directory $SQLExtEventDir does not exits on $($SQLTraceCfg.SQLServer) ! Extended Event Sessions can not be created!"
            Out-Msg -Type WARNING "Verify on SQL Server $($SQLTraceCfg.SQLServer) that the path exist, and SQL Service account has permissions to read/write to this directory!!!"
        }


        if (-not $OnlyValidate) 
        {
            Configure-SQLInstance4DMVTracing  -SQLServerInstance $SQLServerInstance -SQLTraceCfg $SQLTraceCfg -SQLStatus $SQLStatus -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLBlockedThreshold $SQLBlockedThreshold -SQLXEFilterDuration $SQLXEFilterDuration -SQLNumberOfFiles $SQLNumberOfFiles -SQLSizeOfFile $SQLSizeOfFile 
            $SQLStatus = Validate-SQLInstance -SQLServerInstance $SQLServerInstance -SQLTraceCfg $SQLTraceCfg -SQLExtEventDir $SQLExtEventDir -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLBlockedThreshold $SQLBlockedThreshold -SQLMajorVersionMinimum 11
        }

        if($SQLTraceCfg.AXBusinessDBname)
        {
            [Object] $AXSQLServerInstance = Init-SQLServerConnection -SqlServer $SQLTraceCfg.AXBusinessDS;
            <# $AXStatus atributes:
                    AXBusinessDBExist
                    AXBusinessDBPermissionsExist
            #>
            [System.Collections.Hashtable]$AXStatus  = Validate-SQLAXBusinessDB  -SQLServerInstance $AXSQLServerInstance -SQLTraceCfg $SQLTraceCfg -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLStatus $SQLStatus

            if (-not $OnlyValidate) 
            {
                Configure-AXBusinessDB4DMVTracing      -SQLServerInstance $AXSQLServerInstance -AXStatus $AXStatus -SQLTraceCfg $SQLTraceCfg -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLStatus $SQLStatus
                $AXStatus  = Validate-SQLAXBusinessDB  -SQLServerInstance $AXSQLServerInstance -SQLTraceCfg $SQLTraceCfg -SQLTraceServiceaccount $SQLTraceServiceaccount -SQLStatus $SQLStatus
            }
        }
    }
    catch{
        Out-Msg -Type ERROR -Message $_
        $endedWithExceptions=$true
        [string] $ExceptionMessage=$_
    }

    ##### Prepare Result Object
    [bool] $sqlResult=$false
    if ($SQLStatus)
    {
        $sqlResult=$true
        Foreach ($sql in $SQLStatus.GetEnumerator())
        {
            $sqlResult=($sqlResult -and $sql.value)
        }
    }
    if($AXStatus)
    {
        [bool] $axResult=$true

        Foreach ($ax in $AXStatus.GetEnumerator())
        {
            $axResult=($axresult -and $ax.value)
        }
    }

    [System.Collections.Hashtable] $_result=@{SQLStatusDetails=$SQLStatus;SQLStatus=$sqlResult}
    if($AXStatus)
    {
        $_result+=@{AXStatusDetails=$AXStatus;AXStatus=$axResult}
    }

    [bool] $isPrepared=$true

    if ($axResult -ne $null)
    {
        $isPrepared=$axResult
    }


    $isPrepared=($isPrepared -and $sqlResult)

    $_result+=@{SQLInstancePrepared=$isPrepared}
    $_result+=@{hasExceptions=$endedWithExceptions}    
    if($endedWithExceptions)
    {
        if ($ExceptionMessage)
        {
            $_result+=@{ExceptionMessage=$ExceptionMessage}    
        }
    }

return $_result
