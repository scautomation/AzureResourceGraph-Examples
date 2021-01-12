# Azure IaaS Resource Graph Queries

## Purpose
Provide examples on querying Azure IaaS Resources with Kusto

### Count of VM by Status
Resources | where type == "microsoft.compute/virtualmachines"
| extend vmState = tostring(properties.extended.instanceView.powerState.displayStatus)
| extend vmState = iif(isempty(vmState), "VM State Unknown", (vmState))
| summarize count() by vmState

### Count IaaS VMs by Size
Returns count of VMs by their Sku Size.

Resources  
| where type == "microsoft.compute/virtualmachines"  
| summarize Count=count(properties.hardwareProfile.vmSize) by vmSize=tostring(properties.hardwareProfile.vmSize)

### Total IaaS Disk Size
Returns total size of all IaaS Disks in GB

Resources  
| where type contains "microsoft.compute/disks"  
| summarize DiskSizeGB=sum(toint(properties.diskSizeGB))

### Disk Size & Sku by Location
Returns count of Disk size by Sku and Size

Resources  
| where type contains "microsoft.compute/disks"  
| summarize DiskSizeGB=sum(toint(properties.diskSizeGB)) by DiskSku=tostring(sku.name), location

### Count of VMs by Size and Location
Returns Count of VMs by Size, OS, Location  

Resources   
| where type == "microsoft.compute/virtualmachines"  
| summarize Count=count(properties.hardwareProfile.vmSize) by OS=tostring(properties.storageProfile.osDisk.osType), location,  vmSize=tostring(properties.hardwareProfile.vmSize)
  
  
    
### Join Virtual Machine with NICs and Public IPs
Resources  
| where type =~ 'microsoft.compute/virtualmachines'  
| extend nics=array_length(properties.networkProfile.networkInterfaces)  
| mv-expand nic=properties.networkProfile.networkInterfaces  
| where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic)  
| project vmId = id, vmName = name, vmSize=tostring(properties.hardwareProfile.vmSize), nicId = tostring(nic.id)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| join kind=leftouter (  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Resources  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where type =~ 'microsoft.network/networkinterfaces'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| extend ipConfigsCount=array_length(properties.ipConfigurations)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| mv-expand ipconfig=properties.ipConfigurations  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| project nicId = id, privateIP= tostring(ipconfig.properties.privateIPAddress), publicIpId = tostring(ipconfig.properties.publicIPAddress.id), subscriptionId)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; on nicId  
| project-away nicId1  
| summarize by vmId, vmSize, nicId, privateIP, publicIpId, subscriptionId  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| join kind=leftouter (  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Resources  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where type =~ 'microsoft.network/publicipaddresses'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| project publicIpId = id, publicIpAddress = tostring(properties.ipAddress)) on publicIpId  
| project-away publicIpId1  
| sort by publicIpAddress desc
### Join Virtual Machine with Storage Profile
a simple example - Joins the Storage profile with its corresponding Virtual Machine

Resources  
| where type contains "microsoft.compute/disks"  
| project Os=properties.osType,   
		  DiskSku=sku.name,   
		  DiskSizeGB=properties.diskSizeGB,   
		  id = managedBy  
| join (Resources | where type == "microsoft.compute/virtualmachines") on id


#### Complex Example - joined Storage profile, with OS, disk ID, sku, osDiskSize, data disk and data disk count

Resources  
| where type == "microsoft.compute/virtualmachines"  
| extend osDiskId= tostring(properties.storageProfile.osDisk.managedDisk.id)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| join kind=leftouter(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;resources  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where type =~ 'microsoft.compute/disks'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where properties !has 'Unattached'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where properties has 'osType'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| project OS = tostring(properties.osType), osSku = tostring(sku.name), osDiskSizeGB = toint(properties.diskSizeGB), osDiskId=tostring(id))  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;on osDiskId  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| join kind=leftouter(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;resources
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where type =~ 'microsoft.compute/disks'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where properties !has "osType"  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| where properties !has 'Unattached'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| project sku = tostring(sku.name), diskSizeGB = toint(properties.diskSizeGB), id = managedBy  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
| summarize sum(diskSizeGB), count(sku) by id, sku)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;on id  
| project vmId=id, OS, location, resourceGroup, subscriptionId, osDiskId, osSku, osDiskSizeGB, 		 DataDisksGB=sum_diskSizeGB, diskSkuCount=count_sku  
| sort by diskSkuCount desc


