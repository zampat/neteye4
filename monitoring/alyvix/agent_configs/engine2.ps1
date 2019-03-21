Set-StrictMode -Version Latest

function Write-Log($Message) {
    $MessageDate = (Get-Date -Format "yyyyMMdd-HHmmss")
    $MessagePrefix = "[$MessageDate]"

    #Scommentare se si desidera avere output di debug
    #Write-Host $MessagePrefix $Message
}

#1- Carica configurazione ed elenco dei test da file
#2- Applica la retention policy, eliminando i dati troppo vecchi
#3- Esegue il test alyvix; sarà il caso di terminare i processi non ancora conclusi? Forse, non eseguire i test se un processo alyvix risulta ancora in pancia...
#4- Trasferisce i risultati dei test sul server NetEye

#Lettura delle impostazioni di configurazione
### Attenzione, questa parte ancora da fare. Attualmente, rimpiazzata dalle variabili $configuration e $TestList.
$TestsFilePath  = "C:\AlyvixLauncher\alyvix_tests.csv"
$ConfigFilePath = "C:\AlyvixLauncher\engine.ps1.conf"
$TestName       = "test.robot"

$Configuration = @{
    PybotFilePath           = "C:\Python27\Scripts\alyvix_pybot.bat"
    PSCPFilePath            = "C:\Program Files\PuTTY\pscp.exe"
    RemoteServerName        = "ne43.neteye.lab"
    RemoteServerUsername    = "root"
    RemoteServerLogonKey    = "C:\AlyvixLauncher\ne.priv.ppk"
    RemoteServerReportsPath = "/data/alyvix/reports"

}

#Caricamento della lista dei test
Write-Log "Reading test list from file"
$TestList = @{}

$TestData=@{
    Name          = "test.robot"
    Description   = "Simply, a basic test for Alyvix probe. Something just idiot"
    RobotFilePath = "C:\Python27\Lib\site-packages\alyvix\robotproxy\alyvix-testcases\test.robot"
    OutputPath    = "C:\alyvix-reports\test";
    FileByDate    = $true
    DaysToKeep    = 30
    Timeout       = 60
}

$NewTest = New-Object -TypeName PSCustomObject -Property $TestData
$TestList[$NewTest.Name] = $NewTest

Write-Log "Verifying test parameters"
foreach ($Test in $TestList.Values) {
    Write-Log "Verifying test $($Test.Name)"
    if ((Test-Path -Path $Test.RobotFilePath -PathType Leaf) -eq $false) {
        Write-Log "Invalid Robot File Path: $($Test.RobotFilePath)"

        exit -1
    }
    if ((Test-Path -Path $Test.OutputPath -PathType Container) -eq $false) {
        Write-Log "Invalid Output Path: $($Test.OutputPath)"

        exit -1
    }
}

#Verifica dell'esistenza del test specificato
Write-Log "Preparing for running test $TestName"
if ($TestList.ContainsKey($TestName) -eq $false) {
    Write-Log "Test $TestName not defined"

    exit -1
}


#Inizializzazione delle variabili di sessione per il test
$Test = $TestList[$TestName]
$Name           = $Test.Name
$RobotFilePath  = $Test.RobotFilepath
$OutputBasePath = $Test.OutputPath
$FileByDate     = $Test.FileByDate
$DaysToKeep     = $Test.DaysToKeep
$Timeout        = $Test.Timeout

$TestStartTime  = Get-Date
$DaysToKeep     = $Test.DaysToKeep
$OutputPath     = $OutputBasePath
if ($FileByDate) {
    $OutputPath += "\" + $TestStartTime.ToString("yyyyMMdd-HHmmss")
}

#Applicazione della Retention Policy
if ($FileByDate) {
    Write-Log "Performing old data cleanup..."
    $RemovalDate = $TestStartTime.AddDays(-$DaysToKeep)
    $FoldersToRemove = Get-ChildItem -Path $OutputBasePath | Where-Object { $_.LastWriteTime -lt $RemovalDate }
    $FoldersToRemove | Remove-Item -Recurse #-WhatIf
}

#Verifica dell'assenza di processi Alyvix in esecuzione
Write-Log "Ensuring no Python is running on the current server"
$AlyvixProcesses = Get-Process -Name "python" -ErrorAction SilentlyContinue
if ($null -ne $AlyvixProcesses) {
    Write-Log "Found $(($AlyvixProcesses).Count) process(es)"
    exit -1
}

#Esecuzione del test Alyvix
Write-Log "Creating process"
$ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName  = $Configuration.PybotFilePath
$ProcessInfo.Arguments = $RobotFilePath,"--outputdir",$OutputPath
$ProcessInfo.RedirectStandardError  = $true
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.UseShellExecute        = $false
$ProcessInfo.CreateNoWindow         = $true

Write-Log "Starting process"    
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo
$StartResult = $Process.Start()
$Process | Wait-Process -Timeout $Timeout

#Implementare il codice di chiusura forzata dei processi
if ($process.HasExited -eq $false) {
    Write-Host "Test not completed within the specified timeout. Killing process..."
    #$process | Stop-Process -Force
    Write-Host "MI PIACEREBBE KILLARE IL PROCESSO MA MANCA IL CODICE"
    }

$Output = $Process.StandardOutput.ReadToEnd()
$Output

#Trasferimento dei file generati sul server di destinazione


$ServerName     = $Configuration.RemoteServerName
$Username       = $Configuration.RemoteServerUsername
$KeyFile        = $Configuration.RemoteServerLogonKey
$RemoteBasePath = "$($Configuration.RemoteServerReportsPath)/$TestName/"



#$ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
#$ProcessInfo.FileName  = $Configuration.PSCPFilePath
#$ProcessInfo.Arguments = "-p","-q","-r","-i",$KeyFile,"-batch","$OutputBasePath\*","$($Username)@$($ServerName):$($RemoteBasePath)"
#$ProcessInfo.RedirectStandardError  = $true
#$ProcessInfo.RedirectStandardOutput = $true
#$ProcessInfo.UseShellExecute        = $false
#$ProcessInfo.CreateNoWindow         = $true
#
#$Process = New-Object System.Diagnostics.Process
#$Process.StartInfo = $ProcessInfo
#$StartResult = $Process.Start()
#$Process | Wait-Process
