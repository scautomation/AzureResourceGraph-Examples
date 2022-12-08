## Sumarize Network resources
resources  
| where type has "microsoft.network"  
| extend type = case(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/networkinterfaces', "NICs",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/networksecuritygroups', "NSGs",   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == "microsoft.network/publicipaddresses", "Public IPs",   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/virtualnetworks', "vNets",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/networkwatchers/connectionmonitors', "Connection Monitors",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/privatednszones', "Private DNS",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/virtualnetworkgateways', @"vNet Gateways",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/connections', "Connections",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/networkwatchers', "Network Watchers",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/privateendpoints', "Private Endpoints",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/localnetworkgateways', "Local Network Gateways",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/privatednszones/virtualnetworklinks', "vNet Links",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/dnszones', 'DNS Zones',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/networkwatchers/flowlogs', 'Flow Logs',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/routetables', 'Route Tables',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.network/loadbalancers', 'Load Balancers',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;strcat("Not Translated: ", type))  
| summarize count() by type  
| where type !has "Not Translated"

## Public IPs
Returns count of Public IPs and Type

Resources  
| where type == "microsoft.network/publicipaddresses"  
| summarize PIPs=count() by IPType=tostring(properties.publicIPAddressVersion)

## Unassociated NSGs
Resources  
| where type =~ 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets)  
| project Resource=id, resourceGroup, subscriptionId, location


## NSG Rules
Resources  
| where type =~ 'microsoft.network/networksecuritygroups'  
| project id, nsgRules = parse_json(parse_json(properties).securityRules), networksecurityGroupName = name, subscriptionId, resourceGroup , location  
| mvexpand nsgRule = nsgRules  
| project id, location, access=nsgRule.properties.access,protocol=nsgRule.properties.protocol ,direction=nsgRule.properties.direction,provisioningState= nsgRule.properties.provisioningState ,priority=nsgRule.properties.priority,     
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sourceAddressPrefix = nsgRule.properties.sourceAddressPrefix,   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sourceAddressPrefixes = nsgRule.properties.sourceAddressPrefixes,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;destinationAddressPrefix = nsgRule.properties.destinationAddressPrefix,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;destinationAddressPrefixes = nsgRule.properties.destinationAddressPrefixes,   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;networksecurityGroupName, networksecurityRuleName = tostring(nsgRule.name),   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;subscriptionId, resourceGroup,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;destinationPortRanges = nsgRule.properties.destinationPortRanges,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;destinationPortRange = nsgRule.properties.destinationPortRange,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sourcePortRanges = nsgRule.properties.sourcePortRanges,  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sourcePortRange = nsgRule.properties.sourcePortRange    
| extend Details = pack_all()  
| project id, location, access, direction, subscriptionId, resourceGroup, Details

## User Defined Routes

``` kql
resources
| where type =~ 'microsoft.network/routetables'
| project id, routes = parse_json(parse_json(properties).routes), routeTableName = name, subscriptionId, resourceGroup, location
| mvexpand route = routes
| project id,
    location,
    addressPrefix=route.properties.addressPrefix,
    nextHopType=route.properties.nextHopType,
    nextHopIpAddress=route.properties.nextHopIpAddress,
    hasBgpOverride=route.properties.hasBgpOverride,
    routeTableName,
    routeName = tostring(route.name),
    subscriptionId,
    resourceGroup
| extend Details = pack_all()
| project id, routeTableName, location, addressPrefix, nextHopType, nextHopIpAddress, subscriptionId, resourceGroup, Details
```
