# Service Health

KQL examples

Count of each tpye of Service Health issue and count of Resolved, active, etc

```kql
servicehealthresources
| where type =~ 'microsoft.resourcehealth/events'
| extend EventLevel = tostring(properties.EventLevel),
        EventType = tostring(properties.EventType),
        Status = tostring(properties.Status),
        Header = tostring(properties.Header),
        impactType = tostring(properties.impactType),
        Title = tostring(properties.Title),
        Summary = tostring(properties.Summary),
        impactStartTime = todatetime(tolong(properties.ImpactStartTime)), 
        impactMitigationTime = todatetime(tolong(properties.ImpactMitigationTime))
| mv-expand Impact = properties.Impact
| extend Service = tostring(Impact.ImpactedService)
| summarize Informational = countif(EventLevel == "Informational"),
            Warning = countif(EventLevel == "Warning"),
            HealthAdvisory = countif(EventType == "HealthAdvisory"),
            PlannedMaintenance = countif(EventType == "PlannedMaintenance"),
            SecurityAdvisory = countif(EventType == "SecurityAdvisory"),
            ServiceIssue = countif(EventType == "ServiceIssue"),
            Active = countif(Status == "Active"),
            Resolved = countif(Status == "Resolved"),
            NetworkConnectivity = countif(impactType == "NetworkConnectivity"),
            NoImpact = countif(impactType == "NoImpact"),
            ServiceAvailability = countif(impactType == "ServiceAvailability"),
            ServiceManagementOperations = countif(impactType == "ServiceManagementOperations"),
            Other = countif(impactType == "Other" or isempty(impactType))
```

Same as above, but get it by subscription

```kql
servicehealthresources
| where type =~ 'microsoft.resourcehealth/events'
| extend EventLevel = tostring(properties.EventLevel),
        EventType = tostring(properties.EventType),
        Status = tostring(properties.Status),
        Header = tostring(properties.Header),
        impactType = tostring(properties.impactType),
        Title = tostring(properties.Title),
        Summary = tostring(properties.Summary),
        impactStartTime = todatetime(tolong(properties.ImpactStartTime)), 
        impactMitigationTime = todatetime(tolong(properties.ImpactMitigationTime))
| mv-expand Impact = properties.Impact
| extend Service = tostring(Impact.ImpactedService)
| summarize Informational = countif(EventLevel == "Informational"),
            Warning = countif(EventLevel == "Warning"),
            HealthAdvisory = countif(EventType == "HealthAdvisory"),
            PlannedMaintenance = countif(EventType == "PlannedMaintenance"),
            SecurityAdvisory = countif(EventType == "SecurityAdvisory"),
            ServiceIssue = countif(EventType == "ServiceIssue"),
            Active = countif(Status == "Active"),
            Resolved = countif(Status == "Resolved"),
            NetworkConnectivity = countif(impactType == "NetworkConnectivity"),
            NoImpact = countif(impactType == "NoImpact"),
            ServiceAvailability = countif(impactType == "ServiceAvailability"),
            ServiceManagementOperations = countif(impactType == "ServiceManagementOperations"),
            Other = countif(impactType == "Other" or isempty(impactType)) by subscriptionId
```

Gets all Service Health alerts with their current status, Event Type, Level, impact Start Time and Mitigation time as well as any affected resources.

```kql
servicehealthresources
| where type =~ 'microsoft.resourcehealth/events'
| extend EventLevel = tostring(properties.EventLevel),
        EventType = tostring(properties.EventType),
        Status = tostring(properties.Status),
        Header = tostring(properties.Header),
        impactType = tostring(properties.impactType),
        Title = tostring(properties.Title),
        Summary = tostring(properties.Summary),
        impactStartTime = todatetime(tolong(properties.ImpactStartTime)), 
        impactMitigationTime = todatetime(tolong(properties.ImpactMitigationTime))        
| where impactStartTime {TimeRange}
| mv-expand Impact = properties.Impact
| extend Service = tostring(Impact.ImpactedService)
| extend Service = strcat_array(split(Service, "\\"), "-")
| extend Service = strcat_array(split(Service, "&"), "-")
| where Service in ({Services})
| mv-expand Regions = Impact.ImpactedRegions
| extend ImpactedRegions = tostring(Regions.ImpactedRegion)
| where ImpactedRegions in ({Regions})
| summarize arg_max(subscriptionId, EventType, EventLevel, 
                    Status, impactStartTime, impactMitigationTime, 
                    Service, Title, properties, impactType, name), 
            Regions=make_set(ImpactedRegions) by id
| where EventLevel in ({EventLevel})
| where EventType in ({EventType})
| where Status in ({Status})
| join kind = leftouter 
    (servicehealthresources
        | where type =~ 'microsoft.resourcehealth/events/impactedresources'
        | parse id with alertId "/impactedResources/" *
        | extend targetResourceId = tolower(properties.targetResourceId)
        | summarize AffectedResources=make_set(targetResourceId) by alertId) on $left.id == $right.alertId
| extend link = strcat("https://app.azure.com/h/", name)
| extend Details = pack_all()
| project subscriptionId, id, Title, {Columns}, Details, properties, link, name
```

