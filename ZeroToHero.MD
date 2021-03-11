# Azure Resource Graph - Zero to Hero

## Table of Contents  
- [Purpose](#Purpose)  
- [Kusto Query Lanaguage](#Kusto-Query-Language)  
- [Access](#Access)  
- [Tables](#Tables)
    -  [List of Tables](#List-of-Current-Tables)
- [Resource Types](#Resource-Types)
- [Dynamic Types](#Dynamic-Types)
    - [Operators to Know](#Operators-to-Know)
    - [Basic Examples](#Dynamic-Types---Basic-Examples)
    - [Advanced Examples](#Dynamic-Types---Advanced-Examples)
&nbsp;&nbsp;  
## Purpose
To provide a guided walk through of learning Azure Resource Graph from the basics, to advanced queries.
&nbsp;&nbsp;  
&nbsp;&nbsp;  
## Kusto Query Language
Azure Resource Graph uses Kusto Query Language (KQL). It uses a subset of the language, meaning not all scalar operators are available.    

Some notable examples of things you cannot do or use in Azure Resource Graph.    

- You cannot use let  
- You can only do 3 joins  
- Evaluate and its operators are not available  

To see the full language reference refer to the offical docs here. https://docs.microsoft.com/en-us/azure/governance/resource-graph/concepts/query-language  
&nbsp;&nbsp;  
&nbsp;&nbsp;  
## Access
To query resources from your subscriptions, you'll need at least read access to any resources and subscriptions you wish to query.  Azure Resource Graph also supports Azure Lighthouse. 
&nbsp;&nbsp;  
&nbsp;&nbsp;  
## Tables
There are several tables containing various data in Resource Graph.

You do not have to specify a table. If you don't specify a table, it defaults to the resources table.

This query:  
```` kusto
where type =~ 'microsoft.compute/virtualmachines'
````
and this query
```` kusto
resources  
| where type =~ 'microsoft.compute/virtualmachines'
````
Are the same query and produce the same results. I would consider it a better practice to always declare a table, as there are now other tables to choose from than just the resources table.
&nbsp;&nbsp;  
&nbsp;&nbsp;  
### List of Current tables
- resources
- advisorresources
- alertsmanagementresources
- guestconfigurationresources
- maintenanceresources
- patchassessmentresources
- pathcinstallationresources
- policyresources
- recoveryservicesresources
- resourcecontainers
- securityresources
- servicehealthresources
&nbsp;&nbsp;  
&nbsp;&nbsp;
## Resource Types
When querying the resources table, every resource has a resource type, in Azure these are your resource providers. 

To see all available resource types from existing resources
```` kusto
resources  
| distinct type
````
As Azure services have been renamed over the years their provider names have stayed the same. For instance microsoft.compute/operationalinsights/workspaces is the provider name for Log Analytics workspaces. 

**Notable resource type exceptions:
Azure Security Center and Azure Sentinel are Solutions installed on top of Log Analytics workspace. 
Unitl recently Azure Kubernetes service did not have a provider you could find in resource graph.

To query all virtual machines
```` kusto
resources  
| where type =~ 'microsoft.compute/virtualmachines'
  ````

To query all Log Analytics workspaces, change the resource type to microsoft.operationalinsights/workspaces
```` kusto
resources  
| where type =~ 'microsoft.operationalinsights/workspaces'
````
&nbsp;&nbsp;  
&nbsp;&nbsp;  
  
## Dynamic Types 
This section is usefull to any product that uses Kusto Query Language, but is key in extracting useful data out of Azure Resource Graph.   

Once you get beyond querying basic items like resource groups, subscriptions and resource types, you'll find many of the properites of your resources are underneath fields of dynamic type that often hold nested JSON-like values. Sometimes there are multiple levels of nested objects in one field, typically in the properties field of your resources.

This section will aim to show you different ways to accomplish extracting data from dynamic types.

### Operators to know
These are the most common operators you need when working with dynamic types.  
- todynamic()   
- parse_json()  
- mv-expand   
- tolower()  
- tostring()

todynamic and parse_json are synonyms, meaning they perform the exact same funtion. You may see someone use one and someone else use the other, there is no right or wrong way.  
```` kusto
resources  
| where type =~ 'Microsoft.Network/privateEndpoints'  
| extend nics = parse_json(properties.networkInterfaces)  
````
```` kusto
resources  
| where type =~ 'Microsoft.Network/privateEndpoints'  
| extend nics = todynamic(properties.networkInterfaces)
````
these two queries will produce exactly the same result. Each will produce a new field called 'nics' with the resource ID of the private endpoint nic inside it. 

Tolower and tostring are self explanatory, mv-expand expands array objects or dynamic type objects into multiple values.
&nbsp;&nbsp;  
&nbsp;&nbsp; 
&nbsp;&nbsp;     
### Dynamic Types - Basic Examples

The easiest properties to exract are the first layer inside a dynamic object. One of the most common things you may want to extract is the Sku of your resources.   

For Application Services we'll use `microsoft.web/sites` as our resource type  
```` kusto
resources  
| where type =~ 'microsoft.web/sites'  
| extend sku = properties.sku  
````
This query creates replaces the sku field, which is empty for App Services, and populates it with the data from inside the properties field. 

We can also get the current state of our App Service from under the properties field.   
```` kusto
resources  
| where type =~ 'microsoft.web/sites'
| extend State = properties.state  
````
We can traverse as many layers deep in a dynamic object without any problems, until we run into brackets. This example will show you how to get the VM Hardware size of your Azure VMs.
```` kusto
resources  
| where type =~ 'microsoft.compute/virtualmachines'  
| extend Size = properties.hardwareProfile.vmSize  
````
However when we start digging into dynamic types, what gets returned is also dynamic. Sometimes we'll need to convert these to strings. This is especially important when we start joining different resource types by their resource ID. Often these IDs are underneath the properties field.
```` kusto
resources  
| where type =~ 'microsoft.compute/virtualmachines'  
| extend Size = tostring(properties.hardwareProfile.vmSize)
````
adding tostring() around properties.hardwareProfile.vmSize will accomplish this goal. 
&nbsp;&nbsp;  
&nbsp;&nbsp; 
#### Dynamic Types - Advanced Examples
&nbsp;&nbsp;   
Once you delve deeper into the dynamic type objects, you'll find there are certain property types that you cannot use the above dot notation to get. You'll know because they typically have brackets around curly braces like this [{}].  

Application Gateways have a front end IP configuration. Within the properties field in Resource Graph the front end configuration is inside brackets with curly braces.   
We can get at the data by using addressing the first element of an array
```` kusto
resources  
| where type =~ 'microsoft.network/applicationgateways'  
| extend frontEndConfig = properties.frontendIPConfigurations.[0].properties
````
But this is inefficient, what if your data changes per resource type, or you just want all the objects in the array and don't know how many will be in each resource.

this is when we'll want to use mv-expand

```` kusto
resources  
| where type =~ 'microsoft.network/applicationgateways'  
| mv-expand frontEndConfig = properties.frontendIPConfigurations   
````
Now, publicIpId is addressable dot notation, or another mv-expand to get at the data we want. To get the resource ID of the public IP of the Application Gateway we can add an extend on to the end of our previous query.

```` kusto
resources  
| where type =~ 'microsoft.network/applicationgateways'  
| mv-expand frontEndConfig=properties.frontendIPConfigurations  
| extend publicIpId = frontEndConfig = properties.properties.publicIPAddress.id

````
Continuing with Application Gateway example, underneath the same frontEndConfig is a second data property inside brackets. The http listener. To get the resource ID of the http listener we need to do a second mv-expand.

```` kusto

resources  
| where type =~ 'microsoft.network/applicationgateways'  
| mv-expand frontEndConfig=properties.frontendIPConfigurations  
| extend publicIp = frontEndConfig.properties.publicIPAddress.id
| mv-expand httpListeners = frontEndConfig.properties.httpListeners  
````

and finally to get the http listener we can do another extend.
```` kusto
resources  
| where type =~ 'microsoft.network/applicationgateways'  
| mv-expand frontEndConfig=properties.frontendIPConfigurations  
| extend publicIp = frontEndConfig.properties.publicIPAddress.id  
| mv-expand httpListeners = frontEndConfig.properties.httpListeners  
| extend httpListenerId = `httpListeners.id`  
````

## Practical Examples with Joins
These practical examples will show real world scenarios you want to use Resource Graph for. Many of them will require joins. Remember that we can only do 3 joins in Resource Graph. Additionally `join kind=leftouter` is the most common join type you'll want to use. Because you cannot assume that just becasue a VM exists that it has a OS disk, or that a disk exists it has a VM it belongs to. Using `leftouter` will allow you to join resources without eliminating resources by using inner unique joins.

Summarize count VMs by their VM Size.

```` Kusto
Resources
| where type == "microsoft.compute/virtualmachines"
| summarize Count=count() by vmSize=tostring(properties.hardwareProfile.vmSize)
````
Summarize count VMs by their State
```` Kusto
Resources 
| where type == "microsoft.compute/virtualmachines" 
| extend vmState = tostring(properties.extended.instanceView.powerState.displayStatus) 
| extend vmState = iif(isempty(vmState), "VM State Unknown", (vmState)) | summarize count() by vmState
````
This query will join virtual machines with their OS disk and their NIC to get their private ip and publicIP resource ID.
```` Kusto 
resources
| where type == "microsoft.compute/virtualmachines"
| extend osDiskId= tostring(properties.storageProfile.osDisk.managedDisk.id)
    | join(
        resources
        | where type =~ 'microsoft.compute/disks'
        | where properties !has 'Unattached'
        | where properties has 'osType'
        | project OS = tostring(properties.osType), osSku = tostring(sku.name), osDiskSizeGB = toint(properties.diskSizeGB), osDiskId=tostring(id))
	on osDiskId
| extend nics=array_length(properties.networkProfile.networkInterfaces)
| mv-expand nic=properties.networkProfile.networkInterfaces
| where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic)
| extend vmId = id, vmName = name, vmSize=tostring(properties.hardwareProfile.vmSize), nicId = tostring(nic.id)
    | join kind=leftouter (
        resources
        | where type =~ 'microsoft.network/networkinterfaces'
        | extend ipConfigsCount=array_length(properties.ipConfigurations)
        | mv-expand ipconfig=properties.ipConfigurations
        | where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true'
        | project nicId = id, privateIP= tostring(ipconfig.properties.privateIPAddress), publicIpId = tostring(ipconfig.properties.publicIPAddress.id), subscriptionId)
    on nicId
| project id, resourceGroup, OS, osSku, vmSize, privateIP, publicIpId, nicId, properties

````
Join VMs with SQL and Availability Set
```` Kusto 
resources 
| where type == "microsoft.compute/virtualmachines"
| extend vmID = tolower(id)
| extend osDiskId= tolower(tostring(properties.storageProfile.osDisk.managedDisk.id))
    | join kind=leftouter(
		resources
       	| where type =~ 'microsoft.compute/disks'
        | where properties !has 'Unattached'
        | where properties has 'osType'
        | project timeCreated = tostring(properties.timeCreated), OS = tostring(properties.osType), osSku = tostring(sku.name), osDiskSizeGB = toint(properties.diskSizeGB), osDiskId=tolower(tostring(id))) on osDiskId
    | join kind=leftouter(
		resources
		| where type =~ 'microsoft.compute/availabilitysets'
		| extend VirtualMachines = array_length(properties.virtualMachines)
		| mv-expand VirtualMachine=properties.virtualMachines
		| extend FaultDomainCount = properties.platformFaultDomainCount
		| extend UpdateDomainCount = properties.platformUpdateDomainCount
		| extend vmID = tolower(VirtualMachine.id)
		| project AvailabilitySetID = id, vmID, FaultDomainCount, UpdateDomainCount ) on vmID
	| join kind=leftouter(
        resources
		| where type =~ 'microsoft.sqlvirtualmachine/sqlvirtualmachines'
		| extend SQLLicense = properties.sqlServerLicenseType
		| extend SQLImage = properties.sqlImageOffer
		| extend SQLSku = properties.sqlImageSku
		| extend SQLManagement = properties.sqlManagement
		| extend vmID = tostring(tolower(properties.virtualMachineResourceId))
		| project SQLId=id, SQLLicense, SQLImage, SQLSku, SQLManagement, vmID ) on vmID
| project-away vmID1, vmID2, osDiskId1
| extend Details = pack_all()
| project vmID, SQLId, AvailabilitySetID, OS, resourceGroup, location, subscriptionId, SQLLicense, SQLImage,SQLSku, SQLManagement, FaultDomainCount, UpdateDomainCount, Details
````
Query to get Installed Solutions on Log Analytics
```` Kusto 
resources
| where type == "microsoft.operationsmanagement/solutions"
| project Solution=plan.name, Workspace=tolower(tostring(properties.workspaceResourceId)), subscriptionId
	| join kind=leftouter(
		resources
		| where type =~ 'microsoft.operationalinsights/workspaces'
		| project Workspace=tolower(tostring(id)),subscriptionId) on Workspace
| summarize Solutions = strcat_array(make_list(Solution), ",") by Workspace, subscriptionId
| extend AzureSecurityCenter = iif(Solutions has 'Security','Enabled','Not Enabled')
| extend AzureSecurityCenterFree = iif(Solutions has 'SecurityCenterFree','Enabled','Not Enabled')
| extend AzureSentinel = iif(Solutions has "SecurityInsights",'Enabled','Not Enabled')
| extend AzureMonitorVMs = iif(Solutions has "VMInsights",'Enabled','Not Enabled')
| extend AzureMonitorContainers = iif(Solutions has 'ContainerInsights','Enabled','Not Enabled')
| extend AzureAutomation = iif(Solutions has "AzureAutomation",'Enabled','Not Enabled')
| extend ChangeTracking = iif(Solutions has 'ChangeTracking','Enabled','Not Enabled')
| extend UpdateManagement = iif(Solutions has 'Updates','Enabled','Not Enabled')
| extend UpdateCompliance = iif(Solutions has 'WaaSUpdateInsights','Enabled','Not Enabled')
````



