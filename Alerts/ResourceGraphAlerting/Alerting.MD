# Example Alerts for Azure Resource Graph Data
- [Example Alerts for Azure Resource Graph Data](#example-alerts-for-azure-resource-graph-data)
  - [About](#about)
  - [Alerts for Compute Resources](#alerts-for-compute-resources)
    - [Performance \& Heartbeat Alerts](#performance--heartbeat-alerts)
      - [Heartbeat Alert filtered by Resource Tags](#heartbeat-alert-filtered-by-resource-tags)
      - [Alet on high CPU Usage filtered by Resource Tags](#alet-on-high-cpu-usage-filtered-by-resource-tags)
      - [Alert on Disk Free space filtered by Resource Tags](#alert-on-disk-free-space-filtered-by-resource-tags)
      - [Alert on Memory Usage using VMInsights Filtered by Resource Tags](#alert-on-memory-usage-using-vminsights-filtered-by-resource-tags)
    - [Alerts for Azure Update Manager](#alerts-for-azure-update-manager)
      - [Alert on VMs needing patches](#alert-on-vms-needing-patches)
      - [Alert on failed update runs](#alert-on-failed-update-runs)
  - [Alert on Azure Resources](#alert-on-azure-resources)
    - [Alert on Classic Application Insights](#alert-on-classic-application-insights)
    - [Alert on App Service Certification Expiration](#alert-on-app-service-certification-expiration)
    - [Alert on Orhpaned Resources](#alert-on-orhpaned-resources)
      - [Alert on orhpaned public IPs](#alert-on-orhpaned-public-ips)
      - [Alert on orphaned disks](#alert-on-orphaned-disks)
      - [Alert on Empty App Service Plans](#alert-on-empty-app-service-plans)
      - [Alert on Empty Availability Sets](#alert-on-empty-availability-sets)
      - [Alert on Empty Load Balancers](#alert-on-empty-load-balancers)
      - [Alert on Orhpaned NICs](#alert-on-orhpaned-nics)
      - [Alert on unused NAT Gateway](#alert-on-unused-nat-gateway)
  - [Alert on Resource Changes](#alert-on-resource-changes)
    - [Alert on any resource deletion](#alert-on-any-resource-deletion)
    - [vNet Peering state is disconnected](#vnet-peering-state-is-disconnected)

## About
Alerting on Azure Resource Graph data recently went public preview. To succesfully create alerts in Azure Monitor using ARG Data you will need a Managed Identity with reader access to:  

- any resource(s) you want to alert on  
- log analytics reader on a Log Analytics Workspace

[Official Docs](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/azure-monitor-data-explorer-proxy#query-data-in-azure-resource-graph-preview)

[Log Analytics PG Post](https://techcommunity.microsoft.com/t5/azure-observability-blog/query-azure-resource-graph-from-azure-monitor/ba-p/3918298)

My posts on the topic:  
[Managed Identity in Azure Monitor Alerts](https://www.cloudsma.com/2023/08/managed-identity-for-azure-monitor-log-alerts/)

[Query Azure Resource Graph from Log Analytics](https://www.cloudsma.com/2023/09/query-azure-resource-graph-log-analytics/)

[Alerts on ARG Data in Azure Monitor](https://www.cloudsma.com/2023/10/azure-monitor-alerts-from-azure-resource-graph/)

## Alerts for Compute Resources

### Performance & Heartbeat Alerts

#### Heartbeat Alert filtered by Resource Tags  

``` kql
let Threshold = 10m;
arg("").Resources
| where type =~ 'microsoft.compute/virtualmachines' or type =~ 'microsoft.hybridcompute/machines'
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand bagexpansion=array tags limit 400
| extend tagName = tags[0], tagValue = tags[1]
| where tagName == "Environment" and tagValue == "SandlotLab"
| project ResourceId = id, tagName, tagValue
| join (
    Heartbeat
       | summarize LastHeartBeat = max(TimeGenerated), arg_max(SubscriptionId, ResourceGroup, Computer) by ResourceId) 
    on ResourceId
| where LastHeartBeat < ago(Threshold)
| project Computer, ResourceId, ResourceGroup, SubscriptionId, LastHeartBeat

```

#### Alet on high CPU Usage filtered by Resource Tags  

```kql
let Threshold = 90;
arg("").Resources
| where type =~ 'microsoft.compute/virtualmachines' or type =~ 'microsoft.hybridcompute/machines'
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand bagexpansion=array tags limit 400
| extend tagName = tags[0], tagValue = tags[1]
| where tagName == "Environment" and tagValue == "SandlotLab"
| project ResourceId = tolower(id), name, tagName, tagValue
| join(
    Perf
        | where CounterName == "% Processor Time"
        | summarize ['% Processor']=avg(CounterValue) by ResourceId = tolower(_ResourceId)
        | where ['% Processor'] > Threshold)
    on ResourceId
| project ['% Processor'],ResourceId, name, tagName, tagValue
```

#### Alert on Disk Free space filtered by Resource Tags  

```kql
let Threshold = 10;
arg("").Resources
| where type =~ 'microsoft.compute/virtualmachines' or type =~ 'microsoft.hybridcompute/machines'
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand bagexpansion=array tags limit 400
| extend tagName = tags[0], tagValue = tags[1]
| where tagName == "Environment" and tagValue == "SandlotLab"
| project ResourceId = tolower(id), name, tagName, tagValue
| join(
    Perf
        | where CounterName == "% Free Space"
        | summarize ['% Free Space']=avg(CounterValue) by ResourceId = tolower(_ResourceId)
        | where ['% Free Space'] < Threshold
        )
    on ResourceId
| project ['% Free Space'],ResourceId, name, tagName, tagValue
```

#### Alert on Memory Usage using VMInsights Filtered by Resource Tags  

```kql
let NameKey = "Environment";
let NameValue = "Sandlot";
arg("").Resources
| where type =~ 'microsoft.compute/virtualmachines' or type =~ 'microsoft.hybridcompute/machines'
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand bagexpansion=array tags limit 400
| extend tagName = tags[0], tagValue = tags[1]
| where tagName == NameKey and tagValue == NameValue
| join(
    InsightsMetrics
        | where Namespace == "Memory"
        | extend Tags = todynamic(Tags)
        | extend TotalMem = toreal(Tags['vm.azm.ms/memorySizeMB'])
        | summarize RemainMB = avg(TotalMem - Val), 
                    ['Percent Used'] = avg(Val / TotalMem) by _ResourceId
        | where RemainMB < 500 or ['Percent Used'] > 90)
on ResourceId
```

### Alerts for Azure Update Manager  

#### Alert on VMs needing patches  

``` kql
arg("").patchassessmentresources
| where type has "softwarepatches"
| extend id = tolower(id)
| parse id with resourceId "/patchassessmentresults" *
| where isnotnull(properties.kbId)
| extend
    MissingUpdate = tostring(properties.patchName),
    Classification = tostring(properties.classifications[0])
| extend UpdatesNeeded = pack_array(MissingUpdate, Classification)
| summarize UpdatesNeeded = make_set(UpdatesNeeded), Count= count() by resourceId
```

#### Alert on failed update runs  

``` kql
arg("").maintenanceresources
| extend failed = toint(properties.resourceUpdateSummary.failed), 
        timeout = toint(properties.resourceUpdateSummary.timedout), 
        maintenanceId = tostring(properties.maintenanceConfigurationId),
        EndTime = todatetime(properties.endDateTime)
| where failed > 0 or timeout > 0 
| where EndTime > ago(12h)
| summarize Failed=count() by maintenanceId
```

## Alert on Azure Resources

### Alert on Classic Application Insights

``` kql
arg("").Resources
| where type =~ 'microsoft.insights/components'
| extend WorkspaceType = properties.IngestionMode
| where WorkspaceType =~ "ApplicationInsights"
| project id, subscriptionId, resourceGroup, WorkspaceType
```

### Alert on App Service Certification Expiration

```kql
arg("").Resources
| where type =~ "microsoft.web/certificates"
| extend expirationDate = todatetime(properties.expirationDate)
| extend ExpirationStatus = datetime_diff("day", expirationDate, now())
| extend Expiration = case(
                ExpirationStatus <= 30 and ExpirationStatus >= 0, "Expires Soon",
                ExpirationStatus < 0, "Expired",
                ExpirationStatus > 30, "Good","")          
| where Expiration != "Good"
| project id, subscriptionId, expirationDate, Expiration, ExpirationStatus
```

### Alert on Orhpaned Resources  

#### Alert on orhpaned public IPs

``` kql
arg("").resources
| where type =~ "microsoft.network/publicIPAddresses"
| extend ipConfig = tostring(properties.ipConfiguration)
| where isempty(ipConfig)
| project id, subscriptionId, ipConfig
```

#### Alert on orphaned disks  

``` kql
arg("").Resources
| where type has "microsoft.compute/disks"
| extend diskState = tostring(properties.diskState)
| where managedBy == ""
| where not(name endswith "-ASRReplica" or name startswith "ms-asr-" or name startswith "asrseeddisk-")
| project id, subscriptionId
```

#### Alert on Empty App Service Plans

```
arg("").resources
| where type =~ "microsoft.web/serverfarms"
| extend sites = toint(properties.numberOfSites),
        createdTime = todatetime(properties.createdTime)
| where sites == 0 and createdTime < ago(7d)
| summarize EmptyAppServicePlans = count() by subscriptionId
```

#### Alert on Empty Availability Sets

```kql
arg("").Resources
| where type =~ 'Microsoft.Compute/availabilitySets'
| where properties.virtualMachines == "[]"
| summarize EmptyAvailabilitySets = count() subscriptionId
| project-away tenantId
```

#### Alert on Empty Load Balancers

```kql 
arg("").resources
| where type == "microsoft.network/loadbalancers"
| extend properties.backendAddressPools == "[]"
| summarize EmptyLoadBalancers = count() subscriptionId
| project-away tenantId
```

#### Alert on Orhpaned NICs

```kql
arg("").Resources
| where type =~ "microsoft.network/networkinterfaces"
| where isnull(properties.privateEndpoint)
        and isnull(properties.privateLinkService)
        and properties.hostedWorkloads == "[]"
        and properties !has 'virtualmachine'
| summarize EmptyNICs = count() by subscriptionId
```

#### Alert on unused NAT Gateway

```kql
resources
| where type == "microsoft.network/natgateways"
| where isnull(properties.subnets)
| summarize count(type) by subscriptionId
```

## Alert on Resource Changes

### Alert on any resource deletion  

```kql
resourcechanges
| extend Target = tostring(properties.targetResourceType),
        changeType = tostring(properties.changeType),
        targetResourceId = tostring(properties.targetResourceId),
        timestamp = todatetime(properties.changeAttributes.timestamp),
        correlationId = todatetime(properties.changeAttributes.correlationId)
| where changeType == "Delete"
```

### vNet Peering state is disconnected  

``` kql
arg("").resourcechanges
| extend Target = tostring(properties.targetResourceType),
        PeeringStatus = properties.changes["properties.virtualNetworkPeerings[0].properties.peeringState"],
        timestamp = todatetime(properties.changeAttributes.timestamp)
| where Target == "microsoft.network/virtualnetworks"
| extend PeeringStatus = tostring(PeeringStatus.newValue)
| where PeeringStatus != "Connected"
```
