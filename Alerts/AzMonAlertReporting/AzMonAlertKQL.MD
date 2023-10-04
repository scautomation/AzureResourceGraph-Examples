# Azure Monitor Alerts Reporting Queries
- [Azure Monitor Alerts Reporting Queries](#azure-monitor-alerts-reporting-queries)
  - [About](#about)
  - [Summarize Alerts](#summarize-alerts)
    - [Produce summary counts of all severity levels, resolved, fired, and total](#produce-summary-counts-of-all-severity-levels-resolved-fired-and-total)
    - [Summarize Alerts by Subscriptioni](#summarize-alerts-by-subscriptioni)
  - [Detailed Alert View](#detailed-alert-view)
  - [Alert Inventory](#alert-inventory)
  - [Alert Statistics](#alert-statistics)
    - [Daily Alerts by Severity (Time Chart)](#daily-alerts-by-severity-time-chart)
    - [Open Time by Subscription](#open-time-by-subscription)
    - [Open Time by Severity](#open-time-by-severity)
    - [Open Time by Resource Type](#open-time-by-resource-type)
    - [Top 5 Open Time by Resource](#top-5-open-time-by-resource)

## About
These queries are taken from my Azure Monitor Alert Workbook, which can be found here.  [Azure Monitor Alert Workbook](https://github.com/scautomation/Azure-Monitor-Alert-Workbook)

## Summarize Alerts


### Produce summary counts of all severity levels, resolved, fired, and total
```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService)
| extend AlertTarget = case(
        MonitorService == 'ActivityLog Administrative', 'ActivityLog',
        AlertTarget == 'microsoft.insights/components', 'App Insights',
        AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
        AlertTarget)
| summarize Sev0 = countif(Severity == "Sev0"), 
            Sev1 = countif(Severity == "Sev1"), 
            Sev2 = countif(Severity == "Sev2"), 
            Sev3 = countif(Severity == "Sev3"), 
            Sev4 = countif(Severity == "Sev4"),
            Resolved = countif(MonitorCondition == "Resolved"),
            Fired = countif(MonitorCondition == "Fired"),
            Total = count()
```

Same query as above, except this query will allow you to put all values into Tiles in a Workbook. (This is a workaround because Evaluate narrow() isn't available ARG)
```
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService)
| extend AlertTarget = case(
        MonitorService == 'ActivityLog Administrative', 'ActivityLog',
        AlertTarget == 'microsoft.insights/components', 'App Insights',
        AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
        AlertTarget)
| summarize Sev0 = countif(Severity == "Sev0"), 
            Sev1 = countif(Severity == "Sev1"), 
            Sev2 = countif(Severity == "Sev2"), 
            Sev3 = countif(Severity == "Sev3"), 
            Sev4 = countif(Severity == "Sev4"),
            Resolved = countif(MonitorCondition == "Resolved"),
            Fired = countif(MonitorCondition == "Fired"),
            Total = count()
| extend Chart = pack_all()
| project Chart
| mv-expand bagexpansion = array Chart
| project tostring(name = Chart[0]), todouble(val = Chart[1])
| sort by name desc
```

### Summarize Alerts by Subscriptioni
```kql 
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService)
| extend AlertTarget = case(
        MonitorService == 'ActivityLog Administrative', 'ActivityLog',
        AlertTarget == 'microsoft.insights/components', 'App Insights',
        AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
        AlertTarget)
| summarize Sev0 = countif(Severity == "Sev0"), 
            Sev1 = countif(Severity == "Sev1"), 
            Sev2 = countif(Severity == "Sev2"), 
            Sev3 = countif(Severity == "Sev3"), 
            Sev4 = countif(Severity == "Sev4"),
            Resolved = countif(MonitorCondition == "Resolve"),
            Fired = countif(MonitorCondition == "Fired"),
            Total = count() by subscriptionId
| sort by Fired desc
```

## Detailed Alert View

This query seeks to break down all the essential alert types, and allow filtering on them as well as provide signal types for metric and log alerts.

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService),
         ResolvedTime = todatetime(properties.essentials.monitorConditionResolvedDateTime)
| extend AlertTarget = case(
                MonitorService == 'ActivityLog Administrative', 'ActivityLog',
                AlertTarget == 'microsoft.insights/components', 'App Insights',
                AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                AlertTarget)           
| mv-expand Condition = properties.context.context.condition.allOf
| extend SignalLogic = case(
                MonitorService == "VM Insights - Health", strcat("VM Health for ",     properties.essentials.targetResourceName, " Changed from ", properties.context.monitorStateBeforeAlertCreated, " to ", properties.context.monitorStateWhenAlertCreated),
                AlertTarget == "ActivityLog", strcat("When the Activity Log has Category = ", properties.context.context.activityLog.properties.eventCategory, " and Signal name = ", properties.context.context.activityLog.properties.message),
                MonitorService == "Smart Detector", strcat(properties.SmartDetectorName, " Detected failure rate of ", properties.DetectedFailureRate, " above normal failure rate of ", properties.context.NormalFailureRate),
                MonitorService == "Log Analytics", strcat("Alert when ", properties.context.AlertType, " is ", properties.context.AlertThresholdOperator, " threshold ", properties.context.AlertThresholdValue),
                MonitorService == "ActivityLog Autoscale", strcat(properties.context.context.activityLog.operationName, " from ", properties.context.context.activityLog.properties.oldInstancesCount, " to ", properties.context.context.activityLog.properties.newInstancesCount),
                strcat("Alert when metric ", Condition.metricName, Condition.timeAggregation, " is ", Condition.operator, " threshold ", Condition.threshold)),
         Query = case(
                 MonitorService == "Log Alerts V2", tostring(Condition.searchQuery),
                 MonitorService == "Log Analytics", tostring(properties.context.SearchQuery), "N/A"),
         MetricValue = iff(MonitorService == "Log Analytics", toint(properties.context.ResultCount), toint(Condition.metricValue)),
         AffectedResource = iff(AlertTarget == "ActivityLog", properties.context.context.activityLog.subscriptionId, tostring(properties.essentials.targetResourceName))
| extend OpenTime = iff(MonitorCondition == "Resolved", datetime_diff('minute', ResolvedTime, FireTime), datetime_diff('minute', now(), FireTime)),
         Details = pack_all()
| project name, AlertTarget, id, subscriptionId, AffectedResource, MonitorCondition, FireTime, LastModifiedTime, OpenTime, SignalLogic, Query, MetricValue, Details
```

## Alert Inventory

This query seeks to provide an inventory of your alerts as well as provide some basic stats, like how many times that alert has fired and average open time.

```kql
resources
| where type =~ 'microsoft.insights/activitylogalerts'
          or type =~ 'microsoft.alertsmanagement/smartdetectoralertrules'
          or type =~ 'microsoft.insights/scheduledqueryrules'
          or type =~ 'microsoft.insights/alertrules'
          or type =~ 'microsoft.insights/metricalerts'
| extend Enabled = iff(isnotnull(properties.state), properties.state, properties.enabled),
                Severity = properties.severity,
                AutoResolve = properties.autoMitigate,
                Query = properties.source.query
| extend Enabled = case(Enabled == "Enabled", "true", Enabled == "Disabled", "false", Enabled)
| extend Condition = properties.criteria.allOf
| mv-expand Condition
| extend AlertTarget = case(
                properties.criteria contains 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria', 'App Insights',
                type =~ 'microsoft.insights/activitylogalerts', 'ActivityLog',
                type =~ 'microsoft.insights/components', 'App Insights',
                type =~ 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                type =~ 'microsoft.insights/scheduledqueryrules', 'Log Analytics',
                type =~ 'microsoft.alertsmanagement/smartdetectoralertrules', 'App Insights',
                type =~ 'microsoft.insights/components', 'App Insights',
                Condition.metricNamespace =~ 'microsoft.insights/components', 'App Insights',
                Condition.metricNamespace =~ 'Microsoft.OperationalInsights/workspaces', 'Log Analytics',
                tolower(Condition.metricNamespace))
| join kind=leftouter(
              alertsmanagementresources 
                    | extend FireTime = todatetime(properties.essentials.startDateTime), 
                                    LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
                                    MonitorCondition = tostring(properties.essentials.monitorCondition)
                     | extend TimeOpen = iff(MonitorCondition == "Resolved", datetime_diff('minute', LastModifiedTime, FireTime), datetime_diff('minute', now(), FireTime))
                     | where FireTime {TimeRange}
                     | summarize count(), avg(TimeOpen) by name) 
              on name
| extend TimesFired = iff(isnull(count_), 0, count_)
| project-away name1, count_
| extend Scopes = properties.scopes
| extend TargetResource = todynamic(case(
                 type =~ 'microsoft.insights/scheduledqueryrules', properties.source.dataSourceId,
                 type =~ 'microsoft.alertsmanagement/smartdetectoralertrules', properties.scope, properties.scopes))
| extend TargetResource = iff(isnull(TargetResource), Scopes, TargetResource)
| mv-expand TargetResource
| extend ActionGroup = todynamic(case( 
                 type =~ 'microsoft.alertsmanagement/smartdetectoralertrules', properties.actionGroups.groupIds, 
                 type =~ 'microsoft.insights/metricalerts', properties.actions, 
                 type =~ 'microsoft.insights/scheduledqueryrules', properties.action.aznsAction.actionGroup, 
                 type =~ 'microsoft.insights/activitylogalerts', properties.actions.actionGroups, '')) 
| mv-expand ActionGroup 
| extend ActionGroup = case(
                 isnull(ActionGroup), 'No Action Group Assigned', 
                 isnotnull(ActionGroup.actionGroupId), tolower(ActionGroup.actionGroupId), 
                 tolower(ActionGroup)) 
| join kind=leftouter ( 
                 resources 
                       | where type =~ 'microsoft.insights/actiongroups'
                       | extend Email = properties.emailReceivers 
                       | mv-expand Email = Email 
                       | summarize EmailList=make_list(Email.emailAddress) by ActionGroup=tolower(id)) 
                 on ActionGroup
| extend AutoResolve = iff(isnull(AutoResolve), "N/A", AutoResolve),
Details = pack_all()
| project id, name, AlertTarget, avg_TimeOpen, TimesFired, TargetResource, subscriptionId, Enabled, Severity, AutoResolve, Query, EmailList, Details
| sort by TimesFired desc
```

## Alert Statistics

### Daily Alerts by Severity (Time Chart)

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService)
| extend AlertTarget = case(
        MonitorService == 'ActivityLog Administrative', 'ActivityLog',
        AlertTarget == 'microsoft.insights/components', 'App Insights',
        AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
        AlertTarget)
| summarize Sev0 = countif(Severity == "Sev0"), Sev1 = countif(Severity == "Sev1"), Sev2 = countif(Severity == "Sev2"), Sev3 = countif(Severity == "Sev3"), Sev4 = countif(Severity == "Sev4") by bin(FireTime, 1d)
```

### Open Time by Subscription

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService),
         ResolvedTime = todatetime(properties.essentials.monitorConditionResolvedDateTime)
| extend AlertTarget = case(
                MonitorService == 'ActivityLog Administrative', 'ActivityLog',
                AlertTarget == 'microsoft.insights/components', 'App Insights',
                AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                AlertTarget)   
| extend OpenTime = datetime_diff('minute', now(), FireTime)
| summarize avg(OpenTime) by subscriptionId
```

### Open Time by Severity

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService),
         ResolvedTime = todatetime(properties.essentials.monitorConditionResolvedDateTime)
| extend AlertTarget = case(
                MonitorService == 'ActivityLog Administrative', 'ActivityLog',
                AlertTarget == 'microsoft.insights/components', 'App Insights',
                AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                AlertTarget)   
| extend OpenTime = datetime_diff('minute', now(), FireTime)
| summarize avg(OpenTime) by Severity
```

### Open Time by Resource Type

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService),
         ResolvedTime = todatetime(properties.essentials.monitorConditionResolvedDateTime)
| extend AlertTarget = case(
                MonitorService == 'ActivityLog Administrative', 'ActivityLog',
                //AlertTarget == 'microsoft.insights/components', 'App Insights',
                //AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                AlertTarget)   
| extend OpenTime = datetime_diff('minute', now(), FireTime)
| summarize avg(OpenTime) by AlertTarget
```

### Top 5 Open Time by Resource

```kql
alertsmanagementresources
| extend FireTime = todatetime(properties.essentials.startDateTime), 
         LastModifiedTime = todatetime(properties.essentials.lastModifiedDateTime),
         Severity = tostring(properties.essentials.severity), 
         MonitorCondition = tostring(properties.essentials.monitorCondition), 
         AlertTarget = tostring(properties.essentials.targetResourceType), 
         MonitorService = tostring(properties.essentials.monitorService),
         ResolvedTime = todatetime(properties.essentials.monitorConditionResolvedDateTime),
         TargetResource = tostring(properties.essentials.targetResource)
| extend AlertTarget = case(
                MonitorService == 'ActivityLog Administrative', 'ActivityLog',
                AlertTarget == 'microsoft.insights/components', 'App Insights',
                AlertTarget == 'microsoft.operationalinsights/workspaces', 'Log Analytics', 
                AlertTarget)   
| extend OpenTime = datetime_diff('minute', now(), FireTime)
| summarize avg(OpenTime) by TargetResource
| top 5 by avg_OpenTime
| sort by avg_OpenTime desc
```
