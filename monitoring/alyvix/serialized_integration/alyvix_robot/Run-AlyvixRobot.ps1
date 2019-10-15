<#
.SYNOPSIS

Runs an Alyvix based Test Case and, if requested, sends output reports to a remote server via SCP

.DESCRIPTION

This script can run a generic Alyvix Testcase and, after it has done, sends all the produced reports to a remote server.
It can be started with 3 modes, each one corresponding to a different set of parameters. You have to provide a name for the Testcase to be run. The name is quite important because it will be used for storing the reports Alyvix produces.

Mode 1: Run Alyvix Testcase only
This mode will just run an Alyvix Testcase. You have to specify at least a Testcase name, a path for the Testcase Robot file and a path to where reports should be saved.
Additionally, you can specify how reports are saved and kept on disk:
 - Latest: only the last generated report will be kept. Report files should be found in this path:
     <ReportsPath>\<TestcaseName>\Last
 - ByDate: every reportis saved and filed with the Testcase execution date and time. Eventually, reports older than a specific retention will be automatically removed by the script..
           Report files should be found in this path:
      <ReportsPath>\<TestcaseName>\<Testcase date (format: yyyyMMdd-HHmmss)>

Mode 2: Run Alyvix Testcase, then upload reports on a remote Report Server
What said for Mode 1 is also valid for this mode. Additionally, parameters for transferring the generated reports to a remote Report Server (which may also not be a NetEye/Icinga server) must be provided. Data will be copied using PSCP (which must be present on the Alyvix workstation).
You have to provide the remote Report Server name, valid logon credentials (username and password) and a path on the remote server to where store all reports.
If it is necessary, you can provide the path to pscp.exe executable file.
On the remote server will be copied every file and folder present in <ReportsPath>\<TestcaseName>\Last or <ReportsPath>\<TestcaseName>\<Testcase date (format: yyyyMMdd-HHmmss)>. folder.

Mode 3: Run Alyvix Testcase, append useful HTML link to the plugin output, then upload reports on a remote Report Server
What said for Mode 2 is also valid for this mode. With this mode, the script will append to its output some HTML link. These links will then be included in the Plugin Output, that will be interpreted by IcingaWeb2, providing real and valid HTML links.
These links are intendeto do quickly navigate to the current Testcase report and open it. You will have quick links for reports and logs.
Links will be built using <LinksBaseURL> as base for the href attribute of every Anchor. You can provide an Absolute path (like https://myreportserver/alyvix-reports/) or a relative path; a relative path must always start with / (like /alyvix-reports/)

#>

[cmdletbinding(DefaultParameterSetName="EmptySet")]
param(
    [Parameter(ParameterSetName="TestCase",                         Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateNotNull()]
    [ValidateLength(3,30)]
    [ValidateScript( {
        if ($_ -notmatch "^[0-9A-Za-z]+$") {
            throw "Test case name must consist only of letters and numbers."
        }

        return $true
    }
    )]
    [string]$TestCaseName,

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateScript( { 
        if ((Test-Path -Path $_ -PathType Leaf) -eq $false) {
            throw "Robot file $_ does not exists."
        }

        if (((Get-ChildItem -Path $_).Extension).ToLower() -ne ".robot") {
            throw "File $_ is not a valid robot file."
        }
     
        return $true
    }
    )]
    [string]$RobotFilePath,

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [string]$ReportsPath,

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [ValidateScript( { 
        if ((Test-Path -Path $_ -PathType Leaf) -eq $false) {
            throw "Path to Alyvix Pybot file $_ is not valid."
        }

        return $true
    }
    )]
    [string]$AlyvixPybotPath = "C:\Python27\Scripts\alyvix_pybot.bat",

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [ValidateScript( { $_ -ge 0 } )]
    [int]$TestCaseMaxDuration = 60,

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [ValidateSet("ByDate", "KeepLast")]
    [string]$ReportsSaveMode = "ByDate",

    [Parameter(ParameterSetName="TestCase",                         Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [int]$ReportsRetentionHours = 0,


    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportServerName,
    
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,
    
    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$true)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$RemoteReportsPath,

    [Parameter(ParameterSetName="TestCase-UploadReport",            Mandatory=$false)]
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ((Test-Path -Path $_ -PathType Leaf) -eq $false) {
            throw "Unable to locate PSCP at path $_."
        }

        return $true
    }
    )]
    [string]$PSCPPath = "C:\Program Files\PuTTY\pscp.exe",

    
    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$true)]
    [switch]$AppendHTMLLink,

    [Parameter(ParameterSetName="TestCase-UploadReport-AppendLink", Mandatory=$false)]
    [ValidateNotNull()]
    [string]$LinkBaseURL = [String]::Empty
)

Set-StrictMode -Version Latest

#NAGIOS Return values
$EXIT_OK       = 0
$EXIT_WARNING  = 1
$EXIT_CRITICAL = 2
$EXIT_UNKNOWN  = 3

function WritePerfAndQuit($ReturnCode, $PerfString) {
    $ServiceState = "UNKNOWN"

    switch($ReturnCode) {
        0 { $ServiceState = "OK";       break }
        1 { $ServiceState = "WARNING";  break }
        2 { $ServiceState = "CRITICAL"; break }
        3 { $ServiceState = "UNKNOWN";  break }

        default { $ServiceState = "UNKNOWN"; break }
    }

    Write-Output "$ServiceState : $PerfString"

    exit $ReturnCode
}

function EnsureNoAlyvixIsRunning() {
    Write-Verbose "Querying WMI for Python processes..."
    $PythonProcesses = Get-WmiObject -Class Win32_Process -Filter "name='python.exe'"
    $PythonProcesses | ForEach-Object { $_.CommandLine | Write-Verbose }

    Write-Verbose "Looking for Pybot processes..."
    $AlyvixProcesses = $PythonProcesses | Where-Object { $_.CommandLine -like "*robot.run*"}
    if ($null -ne $AlyvixProcesses) {
        Write-Verbose "Found other Alyvix Robot processes running:"
        $AlyvixProcesses | ForEach-Object { $_.CommandLine | Write-Verbose }
        
        WritePerfAndQuit -ReturnCode $EXIT_UNKNOWN -PerfString "At least another Alyvix Robot is running"
    }
}

function GetTestCaseReportsPath($TestCaseName, $ReportsPath) {
    Write-Verbose "Building Testcase Reports Path with:"
    Write-Verbose " TestCaseName: $TestCaseName"
    Write-Verbose " ReportsPath : $ReportsPath"
    
    $TestCaseReportsPath = $ReportsPath + "\" + $TestCaseName
    
    Write-Verbose "Testcase Reports Path: $TestCaseReportsPath"

    return $TestCaseReportsPath
}

function GetCurrentTestCaseReportPath($TestCaseName, $ReportsPath, $SaveMode, $TestCaseStartTime) {
    Write-Verbose "Building Current Testcase Report path with:"
    Write-Verbose " TestCaseName     : $TestCaseName"
    Write-Verbose " ReportsPath      : $ReportsPath"
    Write-Verbose " SaveMode         : $SaveMode"
    Write-Verbose " TestCaseStartTime: $TestCaseStartTime"
    
    $CurrentTestCaseReportPath = GetTestCaseReportsPath -TestCaseName $TestCaseName -ReportsPath $ReportsPath

    switch($SaveMode) {
        "KeepLast" { $CurrentTestCaseReportPath += "\" + "Last";                                          break }
        "ByDate"   { $CurrentTestCaseReportPath += "\" + $TestCaseStartTime.ToString("yyyyMMdd-HHmmss"); break }
    }

    Write-Verbose "Current Testcase Report path: $CurrentTestCaseReportPath"

    return $CurrentTestCaseReportPath
}

function CreateAlyvixProcessInfoData($RobotFilePath, $AlyvixPybotPath, $CurrentTestCaseReportPath) {
    Write-Verbose "Preparing ProcessInfo data for Alyvix Testcase"
    $AlyvixProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo

    $AlyvixProcessInfo.FileName  = $AlyvixPybotPath
    $AlyvixProcessInfo.Arguments = $RobotFilePath,"--outputdir",$CurrentTestCaseReportPath
    $AlyvixProcessInfo.RedirectStandardError  = $true
    $AlyvixProcessInfo.RedirectStandardOutput = $true
    $AlyvixProcessInfo.UseShellExecute        = $false
    $AlyvixProcessInfo.CreateNoWindow         = $false

    Write-Verbose "FileName : $($AlyvixProcessInfo.FileName)"
    Write-Verbose "Arguments: $($AlyvixProcessInfo.Arguments)"

    return $AlyvixProcessInfo
}

function CreatePSCPProcessInfoData($ReportServerName, $Username, $Password, $TestCaseReportPath, $TestCaseRemoteReportPath) {
    Write-Verbose "Preparing ProcessInfo data for PSCP"
    $PSCPProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo

    $PSCPProcessInfo.FileName  = $PSCPPath
    $PSCPProcessInfo.Arguments = "-r","-p","-q","-batch","-pw",$Password,"$TestCaseReportPath","$($Username)@$($ReportServerName):$($TestCaseRemoteReportPath)"
    $PSCPProcessInfo.RedirectStandardError  = $true
    $PSCPProcessInfo.RedirectStandardOutput = $true
    $PSCPProcessInfo.UseShellExecute        = $false
    $PSCPProcessInfo.CreateNoWindow         = $true

    Write-Verbose "FileName : $($PSCPProcessInfo.FileName)"
    Write-Verbose "Arguments: $($PSCPProcessInfo.Arguments)"

    return $PSCPProcessInfo
}

function GetTestCaseRemoteReportsPath($TestCaseName, $RemoteReportsPath) {
    Write-Verbose "Building Testcase Remote Reports Path with:"
    Write-Verbose " TestCaseName     : $TestCaseName"
    Write-Verbose " RemoteReportsPath: $RemoteReportsPath"

    $TestCaseRemoteReportsPath = $TestCaseName
    
    if ($RemoteReportsPath.Length -gt 0) {
        $TestCaseRemoteReportsPath = $RemoteReportsPath + "/" + $TestCaseRemoteReportsPath
    }

    Write-Verbose "Testcase Remote Reports Path: $TestCaseRemoteReportsPath"

    return $TestCaseRemoteReportsPath
}

function GetCurrentTestCaseRemoteReportPath($TestCaseName, $RemoteReportsPath, $SaveMode, $TestCaseStartTime) {
    Write-Verbose "Building Current Testcase Remote Report path with:"
    Write-Verbose " TestCaseName     : $TestCaseName"
    Write-Verbose " RemoteReportsPath: $ReportsPath"
    Write-Verbose " SaveMode         : $SaveMode"
    Write-Verbose " TestCaseStartTime: $TestCaseStartTime"
    
    $CurrentTestCaseRemoteReportPath = GetTestCaseRemoteReportsPath -TestCaseName $TestCaseName -RemoteReportsPath $RemoteReportsPath

    switch($SaveMode) {
        "KeepLast" { $CurrentTestCaseRemoteReportPath += "/" + "Last";                                          break }
        "ByDate"   { $CurrentTestCaseRemoteReportPath += "/" + $TestCaseStartTime.ToString("yyyyMMdd-HHmmss"); break }
    }

    Write-Verbose "Current Testcase Remote Report path: $CurrentTestCaseRemoteReportPath"

    return $CurrentTestCaseRemoteReportPath
}

function GetReportLinkURL($TestCaseName, $LinkBaseURL, $SaveMode, $TestCaseStartTime) {
    Write-Verbose "Building Report Link URL with:"
    Write-Verbose " TestCaseName     : $TestCaseName"
    Write-Verbose " LinkBaseURL      : $LinkBaseURL"
    Write-Verbose " SaveMode         : $SaveMode"
    Write-Verbose " TestCaseStartTime: $TestCaseStartTime"

    $ReportLinkURL = "/" + $TestCaseName

    switch($SaveMode) {
        "KeepLast" { $ReportLinkURL += "/" + "Last";                                         break }
        "ByDate"   { $ReportLinkURL += "/" + $TestCaseStartTime.ToString("yyyyMMdd-HHmmss"); break }
    }

    if (($LinkBaseURL -ne [string]::Empty) -and ("/" -ne $LinkBaseURL)) {
        $ReportLinkURL = $LinkBaseURL + $ReportLinkURL
    }

    Write-Verbose "Report Link URL: $ReportLinkURL"

    return $ReportLinkURL
}

function StartAlyvixProcess($AlyvixProcessInfo) {
    Write-Verbose "Creating Alyvix Process"
    Write-Verbose "FileName : $($AlyvixProcessInfo.FileName)"
    Write-Verbose "Arguments: $($AlyvixProcessInfo.Arguments)"

    $AlyvixProcess = New-Object System.Diagnostics.Process

    Write-Verbose "Starting Alyvix Process"
    $AlyvixProcess.StartInfo = $AlyvixProcessInfo
    $Hole = $AlyvixProcess.Start()

    if ($null -eq $Hole) {
        WritePerfAndQuit -ReturnCode $EXIT_UNKNOWN -PerfString "Unable to start Alyvix Pybot."
    }

    Write-Verbose "Alyvix Process started"

    return $AlyvixProcess
}

function StartPSCPProcess($PSCPProcessInfo) {
    Write-Verbose "Creating PSCP Process"
    Write-Verbose "FileName : $($PSCPProcessInfo.FileName)"
    Write-Verbose "Arguments: $($PSCPProcessInfo.Arguments)"

    $PSCPProcess = New-Object System.Diagnostics.Process

    Write-Verbose "Starting PSCP Process"
    $PSCPProcess.StartInfo = $PSCPProcessInfo
    $Hole = $PSCPProcess.Start()

    if ($null -eq $Hole) {
        WritePerfAndQuit -ReturnCode $EXIT_UNKNOWN -PerfString "Unable to start PSCP."
    }

    Write-Verbose "PSCP Process started"

    return $PSCPProcess
}

function OnAlyvixProcessNotTerminated($AlyvixProcess) {
    Write-Verbose "Alyvix process not terminated after timeout expired"
    WritePerfAndQuit -ReturnCode $EXIT_CRITICAL -PerfString "Current Execution of Alyvix has not terminated. Please manually close every remaining process."
}

function CleanupLocalReports($TestCaseReportsPath, $TestCaseStartTime, $SaveMode, $HoursToKeep) {
    Write-Verbose "Cleaning up older local reports"
    if ($HoursToKeep -lt 1) {
        Write-Verbose "Nothing to remove"
        return
    }

    if ($SaveMode -ne "ByDate") {
        Write-Verbose "Only last report kept: nothing to remove"
        return
    }

    $RemovalDate = $TestCaseStartTime.AddHours(-$HoursToKeep)
    Write-Verbose "Searching for reports older than $RemovalDate"
    $FoldersToRemove = Get-ChildItem -Path $TestCaseReportsPath | Where-Object { $_.LastWriteTime -lt $RemovalDate }
    $FoldersToRemove | Write-Verbose
    Write-Verbose "Removing reports..."
    $FoldersToRemove | Remove-Item -Recurse
    Write-Verbose "Cleanup completed"
}

function CheckParameterSetName() {
    switch ($PSCmdlet.ParameterSetName) {
        "EmptySet" {
            Get-Help -Name $MyInvocation.ScriptName
            
            exit $EXIT_OK
        }
        "TestCase" {
            Write-Verbose "Run Testcase"
            Write-Verbose "TestCaseName         : $TestCaseName"
            Write-Verbose "RobotFilePath        : $RobotFilePath"
            Write-Verbose "ReportsPath          : $ReportsPath"
            Write-Verbose "AlyvixPybotPath      : $AlyvixPybotPath"
            Write-Verbose "TestCaseMaxDuration  : $TestCaseMaxDuration seconds"
            Write-Verbose "ReportsSaveMode      : $ReportsSaveMode"
            Write-Verbose "ReportsRetentionHours: $ReportsRetentionHours hours"
            break
        }
        "TestCase-UploadReport" {
            Write-Verbose "Run Testcase and upload data"
            Write-Verbose "TestCaseName         : $TestCaseName"
            Write-Verbose "RobotFilePath        : $RobotFilePath"
            Write-Verbose "ReportsPath          : $ReportsPath"
            Write-Verbose "AlyvixPybotPath      : $AlyvixPybotPath"
            Write-Verbose "TestCaseMaxDuration  : $TestCaseMaxDuration seconds"
            Write-Verbose "ReportsSaveMode      : $ReportsSaveMode"
            Write-Verbose "ReportsRetentionHours: $ReportsRetentionHours hours"
            Write-Verbose "ReportServerName     : $ReportServerName"
            Write-Verbose "Username             : $Username"
            Write-Verbose "Password             : ***"
            Write-Verbose "RemoteReportsPath    : $RemoteReportsPath"
            Write-Verbose "PSCPPath             : $PSCPPath "
            break
        }
        "TestCase-UploadReport-AppendLink" {
            Write-Verbose "Run Testcase, append link to reports and upload data"
            Write-Verbose "TestCaseName         : $TestCaseName"
            Write-Verbose "RobotFilePath        : $RobotFilePath"
            Write-Verbose "ReportsPath          : $ReportsPath"
            Write-Verbose "AlyvixPybotPath      : $AlyvixPybotPath"
            Write-Verbose "TestCaseMaxDuration  : $TestCaseMaxDuration seconds"
            Write-Verbose "ReportsSaveMode      : $ReportsSaveMode"
            Write-Verbose "ReportsRetentionHours: $ReportsRetentionHours hours"
            Write-Verbose "ReportServerName     : $ReportServerName"
            Write-Verbose "Username             : $Username"
            Write-Verbose "Password             : ***"
            Write-Verbose "RemoteReportsPath    : $RemoteReportsPath"
            Write-Verbose "PSCPPath             : $PSCPPath "
            Write-Verbose "LinkBaseURL          : $LinkBaseURL"
            break
        }
        default {
            throw "Unknown parameter set found: $($PSCmdlet.ParameterSetName)"
        }

    }
}

CheckParameterSetName

Write-Verbose "Initializing variables"

#Saving current time, it will help in generating objects name based always on the same datetime
$StartTime = Get-Date
Write-Verbose "Start time: $StartTime"

#Computing the necessary paths
$TestCaseReportsPath       = GetTestCaseReportsPath -TestCaseName $TestCaseName -ReportsPath $ReportsPath
$CurrentTestCaseReportPath = GetCurrentTestCaseReportPath -TestCaseName $TestCaseName -ReportsPath $ReportsPath -SaveMode $ReportsSaveMode -TestCaseStartTime $StartTime

#Check if another Alyvix Robot is running
Write-Verbose "Ensuring no other Alyvix Process is running"
EnsureNoAlyvixIsRunning

#Starting Test Case
Write-Verbose "Starting Alyvix TestCase"
$ProcessInfo = CreateAlyvixProcessInfoData -RobotFilePath $RobotFilePath -AlyvixPybotPath $AlyvixPybotPath -CurrentTestCaseReportPath $CurrentTestCaseReportPath
$Process     = StartAlyvixProcess -AlyvixProcessInfo $ProcessInfo

Write-Verbose "Waiting for Testcase to terminate"
$Process | Wait-Process -Timeout $TestCaseMaxDuration
if ($Process.HasExited -eq $false) {
    OnAlyvixProcessNotTerminated -AlyvixProcess $Process
}

#Grabbing Robot output
Write-Verbose "Grabbing Testcase output and return code"
$RobotExitCode = $Process.ExitCode
$RobotOutput   = $Process.StandardOutput.ReadToEnd()
if ($RobotOutput[-1] -ne "`n") {
    $RobotOutput += "`r`n"
}

#Cleaning up older reports (If required)
Write-Verbose "Cleaning up older reports"
CleanupLocalReports -TestCaseReportsPath $TestCaseReportsPath -TestCaseStartTime $StartTime -SaveMode $ReportsSaveMode -HoursToKeep $ReportsRetentionHours

if ($PSCmdlet.ParameterSetName -like "*UploadReport*") {
    Write-Verbose "Preparing for uploading data to remote server"
    $TestCaseRemoteReportsPath = GetTestCaseRemoteReportsPath -TestCaseName $TestCaseName -RemoteReportsPath $RemoteReportsPath
    $CurrentTestCaseRemoteReportPath = GetCurrentTestCaseRemoteReportPath -TestCaseName $TestCaseName -RemoteReportsPath $RemoteReportsPath -SaveMode $ReportsSaveMode -TestCaseStartTime $StartTime

    Write-Verbose "Starting Remote Copy process"
	$TestCaseLogPath = $TestCaseReportsPath + "\" + $StartTime.ToString("yyyyMMdd-HHmmss")
    switch($ReportsSaveMode) {
        "KeepLast" { $TestCaseLogPath = $TestCaseReportsPath + "\" + "Last"; break }
        "ByDate"   { $TestCaseLogPath = $TestCaseReportsPath + "\" + $StartTime.ToString("yyyyMMdd-HHmmss"); break }
    }
	Write-Verbose "Testcase Log Path: $TestCaseLogPath"
    $PSCPProcessInfo = CreatePSCPProcessInfoData -ReportServerName $ReportServerName -Username $Username -Password $Password -TestCaseReportPath $TestCaseLogPath -TestCaseRemoteReportPath $TestCaseRemoteReportsPath
    $PSCPProcessInfo = StartPSCPProcess -PSCPProcessInfo $PSCPProcessInfo

    Write-Verbose "Waiting for Remote Copy to end"
    $PSCPProcessInfo | Wait-Process

    Write-Verbose "Remote Copy process return code: $($PSCPProcessInfo.ExitCode)"
    Write-Verbose "Remote Copy process output:"
    Write-Verbose $PSCPProcessInfo.StandardOutput.ReadToEnd()

    if ($PSCmdlet.ParameterSetName -like "*AppendLink*") {
        Write-Verbose "Appending HTML ANchors to reports"
        $ReportLinkURL = GetReportLinkURL -TestCaseName $TestCaseName -LinkBaseURL $LinkBaseURL -SaveMode $ReportsSaveMode -TestCaseStartTime $StartTime

        $ReportAnchor     = "<A target='_blank' href='" + $ReportLinkURL + "/report.html'>Test Case report</A>"
        $LogAnchor        = "<A target='_blank' href='" + $ReportLinkURL + "/log.html'>Test Case log</A>"
        $AllReportsAnchor = "<A target='_blank' href='" + $LinkBaseURL + "'>All Alyvix Reports</A>"

        $RobotOutput += "<p><BR>" + $ReportAnchor + "<BR>" + $LogAnchor + "</p><p>" + $AllReportsAnchor + "</p>"
    }
}

#Printing Robot output and quitting
Write-Verbose "Reporting TestCase output"
$RobotOutput
exit $RobotExitCode
