# Orphaned Resources

## Compute
### Disks
Resources    
| where type has "microsoft.compute/disks"   
| extend diskState = tostring(properties.diskState)  
| where managedBy == "" and diskState != 'ActiveSAS'  
or diskState == 'Unattached' and diskState != 'ActiveSAS'   
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

## Web Apps
Find unused Web API connections - Credit Mohammed Barqawi  

resources  
| where type =~ 'Microsoft.Web/connections'  
|project id  
|join kind= leftouter  
(  
resources  
| where type == 'microsoft.logic/workflows'  
|extend propertiesJson=parse_json(properties)  
|extend ConJson=propertiesJson["parameters"]["$connections"]["value"]  
|mvexpand Conn=ConJson  
|where   notnull(Conn)  
|extend connectionId=extract("\"connectionId\":\"(.*)\"",1,tostring(Conn))  
|project connectionId  
)   on  $left.id==$right.connectionId  