param(
        [string]$ServiceState             = '',
        [string]$ServiceStateType         = '',
        [int]$ServiceAttempt              = ''
    )

if (!$ServiceState -Or !$ServiceStateType -Or !$ServiceAttempt) {
    $scriptName = GCI $MyInvocation.PSCommandPath | Select -Expand Name;
    $date=Get-Date

    write-output ($date.ToString() + ": Computer wurde automatisch rebootet") | out-file -FilePath C:\WorkDir\Log\Protokoll_RestartComputer.log -encoding utf8 -Force -Width 500
    exit 3;
}

# Only restart on the third attempt of a critical event
if ($ServiceState -eq "CRITICAL" -And $ServiceStateType -eq "HARD") {
    Restart-Computer -Force;

} else {
    Write-Host "Not Critical AND HARD" 
}

exit 0;
