# Query Azure Resources by Tags

## Purpose
To provide examples on querying resources in Azure by their Tags.

This section will need the most editing by you, as everyone's tags are different. I have seen for example NS_Application and NS_Environment as well as just Applicaiton and Environment

### Get All Applicaiton Tags
This query will get a list of Application in a Tenant.

resources  
| where tags.NS_Application !=''  
| distinct tostring(tags.Application)  

### Get All Environment Tags
This query will get a list of NS_Enivonrment tags in a Tenant

resources   
| where tags.NS_Environment != ''   
| distinct tostring(tags.Environment)  

### Get All Resources by NS_Application Tag
This query will get all Azure resources based on NS_Application, example uses Lockbox

resources  
| where tags.NS_Application =~ 'EXE - Example Application'

### Get All Resourcs by Environment Tag
this query will get all Azure Resources in Production

resources  
| where tags.NS_Environment =~ 'PRD - Production'

### Get All Azure Resources by Application and Environment

resources  
| where tags.NS_Application =~ 'EXE - Example Application'  
| where tags.NS_Environment =~ 'PRD - Production'