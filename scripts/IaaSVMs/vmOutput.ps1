$everything=$(Search-azGraph -Query "where type != ''  " -First 5000)
while ($($everything.Count) % 5000 -eq 0) { 
$everything=$everything + $(Search-azGraph -Query "where type != '' " -Skip $($everything.Count))
}
 
$VMs=$everything | Where {$_.type -contains 'Microsoft.Compute/virtualMachines'} 
$NICs=$everything | Where {$_.type -contains 'microsoft.network/networkinterfaces'} 
$pubIPs = $everything | Where {$_.type -contains 'microsoft.network/publicipaddresses'}
$NSGs= $everything | Where {$_.type -contains 'microsoft.network/networksecuritygroups'}
$VMSizes = @()
$locations=$VMs | Select location -Unique
foreach ($location in $($locations.location)){
$sizes=get-azvmsize -location $location | Select @{Name="Location";Expression={$location}},Name,NumberOfCores,MemoryInMB,MaxDataDiskCount,OSDiskSizeInMB,ResourceDiskSizeInMB
$VMSizes+=$sizes
}


$output=$VMs `
| select *,@{N='vmSize';E={$_.properties.hardwareProfile.vmSize}} `
| select *,@{N='OSType';E={$_.properties.storageProfile.osDisk.osType}} `
| select *,@{N='Publisher';E={$_.properties.storageprofile.imagereference.publisher}} `
| select *,@{N='Version';E={$_.properties.storageprofile.imagereference.exactVersion}} `
| select *,@{N='CurrentSku';E={$s=$_.VMSize;$l=$_.location;$VMSizes | where {$_.Location -eq $l -and $_.Name -eq $s}}} `
| select *,@{N='NumberOfCores';E={$_.CurrentSku.NumberOfCores}} `
| select *,@{N='MemoryInMB';E={$_.CurrentSku.MemoryInMB}} `
| select *,@{N='MaxDataDiskCount';E={$_.CurrentSku.MaxDataDiskCount}} `
| select *,@{N='ResourceDiskSizeInMB';E={$_.CurrentSku.ResourceDiskSizeInMB}} `
| select *,@{N='NICInfo';E={$NICId=$_.id;$NICs | Where {$_.properties.virtualMachine.id  -eq $NICId }}} `
| select *,@{N='NicName';E={(($_.NICInfo).Name)}} `
| select *,@{N='PrivIP';E={(((($_.NICInfo).Properties).ipConfigurations[0]).properties).privateIPAddress}} `
| select *,@{N='publicIPAddress';E={(($_.PubIPInfo).ipAddress)}}



$new = $output | select name,OSType, Publisher, Version, type,tags,location,resourceGroup, subscriptionId, ResourceId, vmSize,NumberOfCores, MemoryInMB, MaxDataDiskCount, ResourceDiskSizeInMB, NicName, PrivIP | export-csv c:\temp\output6.csv

