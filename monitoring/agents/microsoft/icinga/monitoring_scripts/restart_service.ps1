# Restart Service Script
# Please enable external scripts and external scrips variable before use.

param (
   [string[]]$serviceName
)

if (!$serviceName) {
    
    Write-Host "Please pass the name of the service to restart"
    Write-Host "Usage: restart_service.ps1 <service name>"
    exit 3
}


Foreach ($Service in $ServiceName)
{
  Restart-Service $ServiceName -ErrorAction SilentlyContinue -ErrorVariable ServiceError
  If (!$ServiceError) {
    $Time=Get-Date
    Write-Host "Restarted service $Service at $Time"     
  }
  If ($ServiceError) {
    write-host $error[0] 
    exit 3
  }
}  
 


