param appInsightsName string = 'appi-${uniqueString(resourceGroup().id)}'
param keyVaultName string
param location string
param logAnalyticsName string = 'la-${uniqueString(resourceGroup().id)}'
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    sku: { 
      name: 'PerGB2018' 
    }
  }
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId:logAnalytics.id
    RetentionInDays: 30
  }
  tags: tags
}

resource keyVaultShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource logAnalyticsKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultShared
  name: 'logAnalyticsKey'
  properties: {
    value: logAnalytics.listKeys().primarySharedKey
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output logAnalyticsPrimarySharedKey string = logAnalyticsKeySecret.name
