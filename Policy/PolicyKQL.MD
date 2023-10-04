# Azure Policy Queries
- [Azure Policy Queries](#azure-policy-queries)
  - [Summary Counts](#summary-counts)
    - [Summarize Count of Resource Compliances, Assignments, Unique Policys \& Iniatives Deployed, and Scopes](#summarize-count-of-resource-compliances-assignments-unique-policys--iniatives-deployed-and-scopes)
    - [Compliance by Subscription](#compliance-by-subscription)
  - [Exemptions](#exemptions)
    - [Exemption Stats by Scope](#exemption-stats-by-scope)
    - [Exemption Stats](#exemption-stats)
    - [List Exemptions applied to Policy Definitions](#list-exemptions-applied-to-policy-definitions)
  - [Detailed View of Compliance for All Resources](#detailed-view-of-compliance-for-all-resources)

## Summary Counts

### Summarize Count of Resource Compliances, Assignments, Unique Policys & Iniatives Deployed, and Scopes

```kql
policyresources
| where type =~ 'microsoft.policyinsights/policystates'
| extend AssignmentName = tostring(properties.policyAssignmentName), Initiative = tostring(properties.policySetDefinitionId), 
         PolicyDefintion = tostring(properties.policyDefinitionId), Compliance = tostring(properties.complianceState),
         DefinitionReferrence = tostring(properties.policyDefinitionReferenceId), DefinitionCategory = tostring(properties.policySetDefinitionCategory),
         Scope = tostring(properties.policyAssignmentScope), PolicyAction = tostring(properties.policyDefinitionAction),
         ResourceType = tostring(properties.resourceType)
| summarize ['Resource Assignments'] = count(AssignmentName), 
            ["Initiatives Deployed"] = dcountif(Initiative, isnotnull(Initiative)), 
            ["Policies Deployed"] = dcountif(PolicyDefintion, isempty(Initiative)),
            ["Compliant Resources"] = countif(Compliance == 'Compliant'),
            ["Non Compliant Resources"] = countif(Compliance == 'NonCompliant'),
            ["Exempt Resources"] = countif(Compliance == "Exempt"),
            ["Assignments"] = dcount(AssignmentName),
            ["Scopes"] = dcount(Scope)

// use this section to place into Tiles in a Workbook
| extend Chart = pack_all()
| project Chart
| mv-expand bagexpansion = array Chart
| project tostring(name = Chart[0]), todouble(val = Chart[1])
```

### Compliance by Subscription

```kql
policyresources
| extend ComplianceState=tostring(properties['complianceState']), 
        resourceId=tostring(properties['resourceId']),
        timestamp=todatetime(tostring(properties['timestamp'])),
        policyDefinitionName=tostring(properties['policyDefinitionName'])
| project subscriptionId, ComplianceState, resourceId, timestamp,policyDefinitionName
| summarize max(timestamp) by subscriptionId, resourceId,ComplianceState,policyDefinitionName
| summarize Total = count(), 
            Compliant = countif(ComplianceState == 'Compliant'),
            ['Non-Compliant'] = countif(ComplianceState == 'NonCompliant'),
            Exempt = countif(ComplianceState == 'Exempt'),
            ['Compliance %'] = 100 * countif(ComplianceState == 'Compliant') / count(),
            ['Non-Compliant %'] = 100 * countif(ComplianceState == 'NonCompliant') / count() ,
            ['Exempt %'] = 100 * countif(ComplianceState == 'Exempt') / count() 
    by subscriptionId
| order by ['Compliance %'] desc
```

## Exemptions

### Exemption Stats by Scope

```kql
policyresources 
| where type =~ 'microsoft.authorization/policyexemptions'
| extend policyAssignmentId = tolower(properties.policyAssignmentId),
            DefRecs = properties.policyDefinitionReferenceIds,
            exemptionCategory = tostring(properties.exemptionCategory),
            displayName = tostring(properties.displayName),
            exemptionDescription = tostring(properties.description),
            exemptionExpires = todatetime(properties.expiresOn)
| join kind = leftouter(
    policyresources
        | where type =~ 'microsoft.authorization/policyassignments'
        | project policyAssignmentId = tolower(id), Scope = tostring(properties.scope))
    on policyAssignmentId
| mv-expand DefRecs
| summarize Assignments = dcount(policyAssignmentId), Definitions= dcount(tostring(DefRecs)) by Scope
```

### Exemption Stats

``` kql
policyresources 
| where type =~ 'microsoft.authorization/policyexemptions'
| extend policyAssignmentId = tolower(properties.policyAssignmentId),
         DefRecs = properties.policyDefinitionReferenceIds,
         exemptionCategory = tostring(properties.exemptionCategory),
         displayName = tostring(properties.displayName),
         exemptionDescription = tostring(properties.description),
         exemptionExpires = todatetime(properties.expiresOn),
         exemptionId = tolower(properties.exemptionId),
         exemptionType = tostring(properties.exemptionType),
         exemptionName = tostring(properties.exemptionName)
| extend Time = exemptionExpires - now()
| extend WaiverStatus = iff(exemptionExpires > now(), 
                            strcat('🕒', " Exemption Expires ", 
                                case(Time < 2m, strcat(toint(Time / 1m), ' seconds'), //begin case, if iff is true convert time
                                     Time < 2h, strcat(toint(Time / 1m), ' minutes'), 
                                     Time < 2d, strcat(toint(Time / 1h), ' hours'), 
                                    strcat(toint(Time / 1d), ' days')), ' from now'),//end case
                        iff(isnull(Time), "No Expiration Set","Exemption Expired")) //second iff for null values //end first iff
| summarize Expires30Days = countif(Time < 30d), 
            Expired= countif(WaiverStatus == "ExemptionExpired"), 
            ['Assignments with Exemptions']=dcount(policyAssignmentId), 
            Exemptions = dcount(id),
            ['No Expiration Set'] = countif(WaiverStatus == "No Expiration Set")

// use this section if you want to place the values into Tiles in Workbooks
| extend Chart = pack_all()
| project Chart
| mv-expand bagexpansion = array Chart
| project tostring(name = Chart[0]), todouble(val = Chart[1])
```

### List Exemptions applied to Policy Definitions

```kql 
policyresources 
| where type =~ 'microsoft.authorization/policyexemptions'
| extend policyAssignmentId = tolower(properties.policyAssignmentId),
         DefRecs = properties.policyDefinitionReferenceIds,
         exemptionCategory = tostring(properties.exemptionCategory),
         exemptionId = tolower(id),
         exemptionName = tostring(name),
         expiresOn = todatetime(properties.expiresOn)
| mv-expand policyDefGUID = DefRecs
| extend policyDefinitionId = tolower(strcat("/providers/microsoft.authorization/policydefinitions/",policyDefGUID))
|join kind= leftouter(
    policyresources
        | where type =~ 'microsoft.authorization/policydefinitions'
        | project policyDefinitionId = tolower(id),
                definitionDisplayName = tostring(properties.displayName),
                definitionDescription = tostring(properties.description),
                definitionCategory = tostring(properties.metadata.category))
    on policyDefinitionId
| extend policyDefinitionId = iff(isnull(policyDefGUID), 'No Definitions Found', policyDefinitionId)
| summarize Exemptions = make_set(exemptionName), 
            ExemptionIds = make_set(exemptionId),
            arg_max(expiresOn, policyDefGUID, definitionDisplayName, definitionDescription, definitionCategory)
            by policyDefinitionId
| extend Count = array_length(ExemptionIds)
| extend Details = pack_all()
| project policyDefinitionId, Count, Exemptions, ExemptionIds, definitionDisplayName, Details
```

## Detailed View of Compliance for All Resources

```kql
policyresources
| where type =~ 'microsoft.policyinsights/policystates'
| extend
	resourceId = tostring(properties.resourceId),
	resourceType = tolower(tostring(properties.resourceType)),
	policyAssignmentId = tostring(properties.policyAssignmentId),
	policyDefinitionId = tostring(properties.policyDefinitionId),
	policyDefinitionReferenceId = tostring(properties.policyDefinitionReferenceId),
    policyAssignmentScope = tostring(properties.policyAssignmentScope),
    complianceState = tostring(properties.complianceState),
    assignmentName = tostring(properties.policyAssignmentName)
| extend Details = pack_all()
| project subscriptionId, resourceId, resourceType, assignmentName,policyAssignmentId, policyDefinitionId, complianceState, Details
```