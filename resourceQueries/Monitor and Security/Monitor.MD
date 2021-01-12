# Azure Monitor, Log Analytics, App Insights, Sentinel, Security Center

### Notes on Sentinel and Security Center
At the time of writing: Sentinel and Security Center are not "resources" in the traditional sense, they install as "solutions" on top of a Log Analytics workspace. 

Security Center recently received its own tables for security scores which can be queried from resource graph.

## Summary of Workspaces

resources   
| where type =~ 'microsoft.operationalinsights/workspaces' or type =~ 'microsoft.insights/components'  
| summarize count() by type  
| extend type = case(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/components',   "Application Insights",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.operationalinsights/workspaces', "Log Analytics workspaces",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;strcat(type, type))


## Summary of Azure Monitor Resources
brings back alerts, action groups, workbooks, dashboards, webtest, data collection rules

resources  
| where type has 'microsoft.insights/'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;or type has 'microsoft.alertsmanagement/  smartdetectoralertrules'  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;or type has 'microsoft.portal/dashboards'  
| where type != 'microsoft.insights/components'  
| extend type = case(  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/workbooks', "Workbooks",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/activitylogalerts', "Activity Log Alerts",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/scheduledqueryrules', "Log Search Alerts",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/actiongroups', "Action Groups",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type == 'microsoft.insights/metricalerts', "Metric Alerts",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.alertsmanagement/smartdetectoralertrules','Smart Detection Rules',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.insights/webtests', 'URL Web Tests',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.portal/dashboards', 'Portal Dashboards',  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type =~ 'microsoft.insights/datacollectionrules', 'Data Collection Rules',  
strcat("Not Translated: ", type))  
| summarize count() by type

# Get Active Azure Monitor Alerts

AlertsManagementResources  
| extend AlertStatus = properties.essentials.monitorCondition  
| extend AlertState = properties.essentials.alertState  
| extend AlertTime = properties.essentials.startDateTime  
| extend AlertSuppressed = properties.essentials.actionStatus.isSuppressed  
| extend Severity = properties.essentials.severity  
| where AlertStatus == 'Fired'  
| extend Details = pack_all()  
| project id, name, subscriptionId, resourceGroup, AlertStatus, AlertState, AlertTime, AlertSuppressed, Severity, Details


## Azure Monitor Detailed Resources

resources  
| where type has 'microsoft.insights/'  
     or type has 'microsoft.alertsmanagement/smartdetectoralertrules'  
    or type has 'microsoft.portal/dashboards'  
| where type != 'microsoft.insights/components'
| extend type = case(  
 	type == 'microsoft.insights/workbooks', "Workbooks",  
	type == 'microsoft.insights/activitylogalerts', "Activity Log Alerts",  
	type == 'microsoft.insights/scheduledqueryrules', "Log Search Alerts",  
	type == 'microsoft.insights/actiongroups', "Action Groups",  
	type == 'microsoft.insights/metricalerts', "Metric Alerts",  
	type =~ 'microsoft.alertsmanagement/smartdetectoralertrules','Smart Detection Rules',  
    type =~ 'microsoft.portal/dashboards',   'Portal Dashboards',  
	strcat("Not Translated: ", type))  
| extend Enabled = case(  
	type =~ 'Smart Detection Rules', properties.state,  
	type != 'Smart Detection Rules', properties.enabled,  
	strcat("Not Translated: ", type))  
| extend WorkbookType = iif(type =~ 'Workbooks', properties.category, ' ')  
| extend Details = pack_all()  
| project name, type, subscriptionId, location, resourceGroup, Enabled, WorkbookType, Details


## AppInsights Detailed
resources  
| where type =~ 'microsoft.insights/components'  
| extend RetentionInDays = properties.RetentionInDays  
| extend IngestionMode = properties.IngestionMode  
| extend Details = pack_all()  
| project Resource=id, location, resourceGroup, subscriptionId, IngestionMode, RetentionInDays, Details

## Log Analytics Detailed

resources
| where type =~ 'microsoft.operationalinsights/workspaces'  
| extend Sku = properties.sku.name  
| extend RetentionInDays = properties.retentionInDays  
| extend Details = pack_all()  
| project Workspace=id, resourceGroup, location, subscriptionId, Sku, RetentionInDays, Detailss

## Log Analytics Installed Solutions
note: this is not all available solutions, but are typically the most commonly used in my experience

resources  
| where type == "microsoft.operationsmanagement/solutions"  
| project Solution=plan.name, Workspace=tolower(tostring(properties.workspaceResourceId)), subscriptionId  
	| join kind=leftouter(  
		resources  
		| where type =~ 'microsoft.operationalinsights/workspaces'  
		| project Workspace=tolower(tostring(id)),subscriptionId) on Workspace  
| summarize Solutions = strcat_array  (make_list(Solution), ",") by Workspace, subscriptionId  
| extend AzureSecurityCenter = iif(Solutions has 'Security','Enabled','Not Enabled')  
| extend AzureSecurityCenterFree = iif(Solutions has 'SecurityCenterFree','Enabled','Not Enabled')  
| extend AzureSentinel = iif(Solutions has "SecurityInsights",'Enabled','Not Enabled')  
| extend AzureMonitorVMs = iif(Solutions has "VMInsights",'Enabled','Not Enabled')  
| extend ServiceDesk = iif(Solutions has "ITSM Connector",'Enabled','Not Enabled')  
| extend AzureAutomation = iif(Solutions has "AzureAutomation",'Enabled','Not Enabled')  
| extend ChangeTracking = iif(Solutions has 'ChangeTracking','Enabled','Not Enabled')  
| extend UpdateManagement = iif(Solutions has 'Updates','Enabled','Not Enabled')  
| extend UpdateCompliance = iif(Solutions has 'WaaSUpdateInsights','Enabled','Not Enabled')  
| extend AzureMonitorContainers = iif(Solutions has 'ContainerInsights','Enabled','Not Enabled')    
| extend KeyVaultAnalytics = iif(Solutions has 'KeyVaultAnalytics','Enabled','Not Enabled')  
| extend SQLHealthCheck = iif(Solutions has 'SQLAssessment','Enabled','Not Enabled')

## Security Score by Subscription

securityresources  
| where type == "microsoft.security/securescores"  
| extend subscriptionSecureScore = round(100 * bin((todouble(properties.score.current))/ todouble(properties.score.max), 0.001))  
| where subscriptionSecureScore > 0  
| project subscriptionSecureScore, subscriptionId  
| order by subscriptionSecureScore asc

## Security Score by Controls

SecurityResources   
| where type == 'microsoft.security/securescores/securescorecontrols'   
| extend SecureControl = properties.displayName, unhealthy = properties.unhealthyResourceCount, currentscore = properties.score.current, maxscore = properties.score.max, subscriptionId  
| project SecureControl , unhealthy, currentscore, maxscore, subscriptionId