# Azure RBAC Queries

This query will extract all properties for RBAC assignments

```kql
authorizationresources
| where type =~ 'microsoft.authorization/roleassignments'
| extend roleDefinitionId = tolower(properties.roleDefinitionId),
        principalType = tostring(properties.principalType),
        GUID = tostring(properties.principalId),
        createdOn = todatetime(properties.createdOn),
        updatedOn = todatetime(properties.updatedOn),
        createdBy = tostring(properties.createdBy),
        updatedBy = tostring(properties.updatedBy),
        scope = tostring(properties.scope)
```

This query will get all role definitions

```kql
authorizationresources
| where type =~ 'microsoft.authorization/roledefinitions'
| extend roleName = tostring(properties.roleName),
        roleType = tostring(properties.type),
        description = tostring(properties.description),
        isServiceRole = tostring(properties.isServiceRole),
        permissions = todynamic(properties.permissions),
        roleDefinitionId = tolower(id)
```