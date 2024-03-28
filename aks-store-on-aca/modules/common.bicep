param environment string
param keyVaultName string
param location string
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-aca-${environment}'
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
  name: 'appi-aca-${environment}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    RetentionInDays: 30
    WorkspaceResourceId: logAnalytics.id    
  }
  tags: tags
}

resource appInsightsConnStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: '${appInsights.name}-connection-string'
  properties: {
    attributes: {
      enabled: true
    }
    value: appInsights.properties.ConnectionString
  }
  tags: tags
}

resource logAnalyticsKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: '${logAnalytics.name}-key'
  properties: {
    attributes: {
      enabled: true
    }
    value: logAnalytics.listKeys().primarySharedKey
  }
  tags: tags
}

resource kvDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: keyVaultName
  scope: keyVault  
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output logAnalyticsKey string = logAnalyticsKeySecret.name
output appInsightsConnectionString string = appInsightsConnStringSecret.name
