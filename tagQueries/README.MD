# Query Azure Resources by Tags
- [Query Azure Resources by Tags](#query-azure-resources-by-tags)
  - [Purpose](#purpose)
    - [Get all tag Key Value pairs](#get-all-tag-key-value-pairs)
    - [Alternate way to Expand all Tags](#alternate-way-to-expand-all-tags)
    - [Summarize Count of resources by Tag name](#summarize-count-of-resources-by-tag-name)
    - [Summarize Count of resources for each Tag name and value](#summarize-count-of-resources-for-each-tag-name-and-value)
    - [Summarize Count of Resource Types by Tag name and value](#summarize-count-of-resource-types-by-tag-name-and-value)

## Purpose

To provide examples on querying resources in Azure by their Tags.

### Get all tag Key Value pairs

``` kql
resources 
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
```

### Alternate way to Expand all Tags

```kql
resources
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand bagexpansion=array tags limit 400
| extend tagName = tags[0], tagValue = tags[1]
```

### Summarize Count of resources by Tag name

```kql
resources 
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
| summarize count() by tagName
| order by ['count_'] desc
```

### Summarize Count of resources for each Tag name and value

``` kql
resources 
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
| summarize count() by tagName, tagValue
| order by ['count_'] desc
```

### Summarize Count of Resource Types by Tag name and value

```kql
resources 
| where isnotempty(tags)
| where tags !has "hidden-"
| mv-expand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
| summarize count() by type, tagName, tagValue 
| order by ['count_'] desc
```
