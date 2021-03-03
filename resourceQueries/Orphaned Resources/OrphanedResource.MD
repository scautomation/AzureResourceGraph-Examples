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
| where type has "microsoft.network/networkinterfaces"  
| where "{nicWithPrivateEndpoints}" !has id    
| where properties !has 'virtualmachine'  
| project id, resourceGroup, location, subscriptionId


### Availability Sets

resources  
| where type =~ 'microsoft.compute/availabilitysets'  
| extend VirtualMachines = array_length(properties.virtualMachines)  
| where VirtualMachines == 0  

## Networking
### NSGs
Resources  
| where type =~ 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets)  
| project Resource=id, resourceGroup, subscriptionId, location  