param environment string
param location string
param managedIdentityId string
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-aca-helloworld-${environment}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    retentionInDays: 30
    sku: { 
      name: 'PerGB2018' 
    }
  }
  tags: tags
}

output logAnalyticsWorkspaceId string = logAnalytics.id
