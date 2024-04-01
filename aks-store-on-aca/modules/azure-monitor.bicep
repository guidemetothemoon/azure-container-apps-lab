param amplsPrivateDnsZones array
param environment string
param keyVaultName string
param location string
param locationPrefix string
param managedIdentityId string
param subnetId string
param tags object


var privateDnsZoneConfigs = [ for zone in amplsPrivateDnsZones : {
  name: replace(zone, '.', '-')
  properties: {
    privateDnsZoneId:  resourceId('Microsoft.Network/privateDnsZones', zone)
  }
}]

resource keyVaultACA 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource ampls 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: 'ampls-${locationPrefix}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-aca-${environment}'
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
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

resource logAnalyticsAMPLSConnection 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: 'ampls-${logAnalytics.name}'
  parent: ampls
  properties: {
    linkedResourceId: logAnalytics.id
  }
}

resource privateEndpointAMPLS 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-${ampls.name}'
  location: location
  properties: {
    customNetworkInterfaceName: '${ampls.name}-nic-deluxe'
    privateLinkServiceConnections: [
      {
        name: 'psc-${ampls.name}'
        properties: {
          privateLinkServiceId: ampls.id
          groupIds: [
            'azuremonitor'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  dependsOn: [logAnalyticsAMPLSConnection]
  tags: tags
}

resource amplsPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  name: 'default'
  parent: privateEndpointAMPLS
  properties: {
    privateDnsZoneConfigs: privateDnsZoneConfigs
  }
}

resource logAnalyticsKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACA
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
  scope: keyVaultACA
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
