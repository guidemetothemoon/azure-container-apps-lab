param location string
param managedIdentityId string
param tags object

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: 'cae-aca-store'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  tags: tags
}


output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output environmentId string = containerAppsEnvironment.id
