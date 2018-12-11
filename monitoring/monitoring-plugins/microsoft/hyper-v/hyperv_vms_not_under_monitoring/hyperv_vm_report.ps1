# Variables


# path and filename for report file
$VMS = get-vm
$computers = $Env:COMPUTERNAME

# put todays date and time in the file
#echo "Date report was ran" | out-file $file
#get-date | out-file $file -append

# get the vhost uptime
$obj_host = Get-CimInstance Win32_OperatingSystem -comp $computers | Select @{Name="VHostName";Expression={$_."csname"}},@{Name="Uptime";Expression={(Get-Date) - $_.LastBootUpTime}},LastBootUpTime
$obj_host_config = Get-VMHost | Select @{Name="VHostName";Expression={$_."Name"}},@{N="RAM_GB";E={""+ [math]::round($_.Memorycapacity/1GB)}},logicalprocessorcount,virtualharddiskpath,virtualmachinepath

$host_name = $obj_host.VHostName.toString()

Write-Host "Hyper-V Host " $obj_host.VHostName "(Uptime:" $obj_host.Uptime.Hours "Days, " $obj_host.Uptime.Hours "Hours, " $obj_host.Uptime.Minutes" Minutes) has" $obj_host_config.LogicalProcessorCount "CPUs, "$obj_host_config.RAM_GB " GB RAM. Virtualharddiskpath is "$obj_host_config.VirtualHardDiskPath " Running VMs: "$VMS.Count" | running_vms="$VMS.Count";;"

$outputArray = ""
foreach($VM in $VMS)
    { 
      $VMsRAM = [math]::round($VM.Memoryassigned/1GB)
      $VMsCPU = $VM.processorCount
      $VMsState = $VM.State
      $VMsStatus = $VM.Status
      $VMsUptime = $VM.Uptime
      $VMsAutomaticstartaction = $VM.Automaticstartaction
      $VMsIntegrationServicesVersion = $VM.IntegrationServicesVersion
      $VMsReplicationState = $VM.ReplicationState

      $VMsIP = Get-VMNetworkAdapter -VMName $VM.Name
   
#    $output = new-object psobject
#    $output | add-member noteproperty "VM Name" $VM.Name
#    $output | add-member noteproperty "RAM(GB)" $VMsRAM
#    $output | add-member noteproperty "vCPU" $VMsCPU
#    $output | add-member noteproperty "State" $VMsState
#    $output | add-member noteproperty "Status" $VMsStatus
#    $output | add-member noteproperty "Uptime" $VMsUptime
#     $output | add-member noteproperty "Start Action" $VMsAutomaticstartaction
#     $output | add-member noteproperty "Integration Tools" $VMsIntegrationServicesVersion
#     $output | add-member noteproperty "Replication State" $VMsReplicationState
#     $output | add-member noteproperty "VHD Path" $VHDs.Path
#     $output | add-member noteproperty "Size GB" $VHDsGB
#     $output | add-member noteproperty "VHD Type" $VHDs.vhdtype
#     $output | add-member noteproperty "VHD Format" $VHDs.vhdformat
#     $output | add-member noteproperty "DVD Media Type" $VMDVD.dvdmediatype
#     $output | add-member noteproperty "DVD Media Path" $VMDVD.path
#      $outputArray += $output
      Write-Host "VM" $VM.Name "(IP: " $VMsIP.IPAddresses ") has: " $VMsRAM "RAM(GB)" $VMsCPU "vCPU. State:" $VMsState "Uptime:" $VMsUptime
     }
     


#echo "VHOST Server IP Addresses and NIC's" | out-file $file -append
#Get-WMIObject win32_NetworkAdapterConfiguration |   Where-Object { $_.IPEnabled -eq $true } | Select IPAddress,Description | format-table -autosize

#echo "VHOST Server drive C: Disk Space" | out-file $file -append
# to get D: drive add ,D after C  - E: drive ,E etc.
#Get-psdrive C | Select Root,@{N="Total(GB)";E={""+ [math]::round(($_.free+$_.used)/1GB)}},@{N="Used(GB)";E={""+ [math]::round($_.used/1GB)}},@{N="Free(GB)";E={""+ [math]::round($_.free/1GB)}} |format-table -autosize | out-file $file -append

#echo "VHosts virtual switch(s) information" | out-file $file -append
#get-vmswitch * | out-file $file -append
