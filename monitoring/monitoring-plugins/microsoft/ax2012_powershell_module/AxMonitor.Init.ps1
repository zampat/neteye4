#Write-Host $PSScriptRoot
if(Test-Path $PSScriptRoot\Microsoft.Dynamics.BusinessConnectorNet.dll) {
    Add-Type -Path $PSScriptRoot\Microsoft.Dynamics.BusinessConnectorNet.dll
}
if(Test-Path $PSScriptRoot\Microsoft.Dynamics.Framework.Metadata.AX.dll) {
    Add-Type -Path $PSScriptRoot\Microsoft.Dynamics.Framework.Metadata.AX.dll
}
if(Test-Path $PSScriptRoot\Microsoft.Dynamics.AX.ManagementPackSupport.dll) {
    Add-Type -Path $PSScriptRoot\Microsoft.Dynamics.AX.ManagementPackSupport.dll
}
if(Test-Path $PSScriptRoot\AxMonitor.DIXFservice.dll) {
    Add-Type -Path $PSScriptRoot\AxMonitor.DIXFservice.dll
}
if(Test-Path $PSScriptRoot\AxMonitor.HelpService.dll) {
    Add-Type -Path $PSScriptRoot\AxMonitor.HelpService.dll
}
if(Test-Path $PSScriptRoot\Microsoft.Dynamics.AX.Client.ClientConfigurationModel.dll) {
    Add-Type -Path $PSScriptRoot\Microsoft.Dynamics.AX.Client.ClientConfigurationModel.dll
}
if(([System.AppDomain]::CurrentDomain.GetAssemblies()|where { $_.ManifestModule -like "System.ServiceModel.dll"}).Count -eq 0)
{
    [Reflection.Assembly]::LoadWithPartialName("System.ServiceModel")|Out-Null
}
if(Test-Path $PSScriptRoot\Microsoft.Dynamics.AX.Framework.Tools.DMF.ServiceProxy.dll) {
    Add-Type -Path $PSScriptRoot\Microsoft.Dynamics.AX.Framework.Tools.DMF.ServiceProxy.dll
}
