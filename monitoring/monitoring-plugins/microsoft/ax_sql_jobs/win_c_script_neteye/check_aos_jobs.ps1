## EXAMPLE . .\check_overdue_BatchJobs.ps1 -SQLServer BOSAXDU1 -AXDBName AX6_UAT
Param
(
  [String]$SQLServer =$(throw '- Need SQL Server name and instance'),
  [String]$AXDBName =$(throw '- Need AX Business Database Name'),
  [int]$BatchOverdue = 10,
  [int]$FreeJobs = 0,
  [boolean]$test=$false
)

$0              = $myInvocation.MyCommand.Definition
#$env:dp0        = [System.IO.Path]::GetDirectoryName($0)
#$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$DBServer = $SQLServer 
#$DBServer = 'HH1-AXDB01'
$DBname= $AXDBName #'AX_PROD'
$timeoverdueinminutes="$BatchOverdue"

$script_path = $PSScriptRoot
$DBscript_chk_jobs_running_BatchTask = "$script_path\batch_runningJobs.sql"
$DBscript_chk_jobs_overdue_BatchTask = "$script_path\batch_overdueJobs.sql"

[int]$int_retCode = 3
[String]$str_outSummary = ""
[String]$str_outDetails
[String]$str_outPerfdata

#Add snap-ins and create parameters in the correct format
if (-not(Get-Module -Name SQLPS)) {
    if (Get-Module -ListAvailable -Name SQLPS) {
        Push-Location
        Import-Module -Name SQLPS -DisableNameChecking
        Pop-Location
    }
}

$DBParam1 = "timeoverdueinminutes=" + $timeoverdueinminutes
$DBParams = $DBParam1

$rows_running=Invoke-Sqlcmd -InputFile $DBscript_chk_jobs_running_BatchTask -Variable $DBParams -Serverinstance $DBServer -Database $DBname
$rows_overdue=Invoke-Sqlcmd -InputFile $DBscript_chk_jobs_overdue_BatchTask -Variable $DBParams -Serverinstance $DBServer -Database $DBname

foreach($row in $rows_overdue)
{
    
    [string] $line_str= "Overdue Jobs on DB: $($row.DBName) and Group-ID: $($row.Groupid): $($row.cntBatchOverdue) Jobs over  $timeoverdueinminutes Minutes. Details: DB Server: $($row.DBServername), SQL-Instance: $($row.SQLInstance) with Total Minutes waiting $($row.TotalOverdueMinutes) (Minutes x Jobs)"
    $str_outDetails += $line_str + "\n"
    $str_outPerfdata += "$($row.DBName)_$($row.Groupid)_overdue_jobs=$($row.cntBatchOverdue);0;0 "

    $int_retCode = 1;
    $str_outSummary += "Warning: Job $($row.DBName) of Group $($row.Groupid) is over $timeoverdueinminutes Minutes. "
    
}

foreach($row in $rows_running)
  {
    
    [string] $line_str= "Running Jobs: AOS Server: $($row.aosserver) Instance: $($row.AOSInstance) FreeJobs: $($row.freeBatchSessions)/$($row.maxBatchSessions)  RunningJobs: $($row.runningBatchSessions)"
    $str_outDetails += $line_str + "\n"
    $str_outPerfdata += "$($row.aosserver)_$($row.AOSInstance)_free=$($row.freeBatchSessions);0;0;0;0 $($row.aosserver)_$($row.AOSInstance)_running=$($row.runningBatchSessions);0;$($row.maxBatchSessions);0;$($row.maxBatchSessions) "
    
    IF ($int_retCode -eq 3) {
        $int_retCode = 0;
        $str_outSummary += "OK: There are no overdue Jobs. "
    }
}

Write-Host "$str_outSummary \n$str_outDetails | $str_outPerfdata"
exit $int_retCode
