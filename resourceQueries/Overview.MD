# General Azure Resource Queries

## Purpose
Provides examples of how to query Azure Resources with Kusto Query Language

### All Resources
Returns count of all Azure Resources

``` KQL
Resources | summarize count()
```

### Count Subscriptions and Resource Groups
Returns count of Subscriptions and Resource Groups

```KQL 
resourcecontainers   
| where type has "microsoft.resources/subscriptions/resourcegroups"
| summarize Count=count(type) by type, subscriptionId 
| extend type = replace(@"microsoft.resources/subscriptions/resourcegroups", @"Resource Groups", type)
```

### Count Resources by Type
While everything is technically a resource in Azure. Counting VM extensions and Disks for an overview seems counter productive, thus I exclude a few items from being captured in this query.

Resources 
| where type != 'microsoft.compute/disks'   
| where type != 'microsoft.compute/virtualmachines/extensions'  
| where type !has 'microsoft.insights'  
| where type != 'microsoft.operationsmanagement/solutions'  
| where type != 'microsoft.compute/images'  
| where type != 'microsoft.netapp/netappaccounts/capacitypools/volumes'  
| extend type = case(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.automation/automationaccounts', 'Automation Accounts',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.operationalinsights/workspaces', 'Log Analytics Workspaces',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.netapp/netappaccounts', 'NetApp Accounts',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.web/serverfarms', "App Service Plans",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.web/sites', "App Services",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ "microsoft.compute/virtualmachines", "Azure Compute",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ "microsoft.logic/workflows", "LogicApps",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.keyvault/vaults', "Key Vaults",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.keyvault/vaults', "Hybrid Compute",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.storage/storageaccounts', "Storage Accounts",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.compute/availabilitysets', 'Availability Sets',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.insights/components','Application Insights',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.desktopvirtualization/applicationgroups', 'WVD Application Groups',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.desktopvirtualization/workspaces', 'WVD Workspaces',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.desktopvirtualization/hostpools', 'WVD Hostpools',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.recoveryservices/vaults', 'Backup Vaults',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.insights/webtests', 'URL Web Tests',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.web/connections', 'LogicApp Connectors',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.web/customapis','LogicApp API Connectors',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.managedidentity/userassignedidentities','Managed Identities',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.storagesync/storagesyncservices', 'Azure File Sync',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.hybridcompute/machines', 'ARC Machines',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type has 'microsoft.network', 'Network Resources',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;strcat("Not Translated: ", type))  
| summarize count() by type  
| where type !has "Not Translated"