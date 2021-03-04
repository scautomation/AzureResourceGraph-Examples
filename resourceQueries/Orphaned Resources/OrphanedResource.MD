# Orphaned Resources

## Compute
### Disks
Resources    
| where type has "microsoft.compute/disks"   
| extend diskState = tostring(properties.diskState)  
| where managedBy == ""  
    or diskState == 'Unattached'  
| project id, diskState, resourceGroup, location, subscriptionId


### NICS
resources  
| where type =~ "microsoft.network/networkinterfaces"  
| join kind=leftouter (resources  
| where type =~ 'microsoft.network/privateendpoints'  
| extend nic = todynamic(properties.networkInterfaces)  
| mv-expand nic  
| project id=tostring(nic.id) ) on id  
| where isempty(id1)  
| where properties !has 'virtualmachine'    
| project id, resourceGroup, location, subscriptionId  


### Availability Sets

resources  
| where type =~ 'microsoft.compute/availabilitysets'  
| extend VirtualMachines = array_length(properties.virtualMachines)  
| where VirtualMachines == 0  

## Public IPs
resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend IpConfig = properties.ipConfiguration.id
| where isempty(IpConfig)
## Networking
### NSGs
Resources  
| where type =~ 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets)  
| project Resource=id, resourceGroup, subscriptionId, location  