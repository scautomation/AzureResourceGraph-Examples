# VM Output

## Purpose
Provides a CSV output of all Azure VMs in an environment. Uses combination of Resource Graph and Azure Powershell to extract fields.

### Notes
recommend to run in Powershell core. In windows Powershell it only queries the active subscription, in Powershell Core it queries all subscriptions in the tenant.