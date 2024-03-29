param subnetId string
param dnsZoneId string
param dnsZoneName string
param fileShareName string
param keyVaultName string
param location string
param logAnalyticsWorkspaceId string
param storageName string = 'store${uniqueString(resourceGroup().id)}'
param tags object

resource keyVaultACAShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageName
  location: location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: subnetId
        }
      ]
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: tags
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}

resource storageDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: storageName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource fileDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: fileService.name
  scope: fileService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource privateEndpointStorageAccount 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-${storageAccount.name}'
  location: location  
  properties: {
    customNetworkInterfaceName: '${storageAccount.name}-nic-deluxe'
    privateLinkServiceConnections: [
      {
        name: 'psc-${storageAccount.name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['file']
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  tags: tags
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  name: '${privateEndpointStorageAccount.name}-dns-zone-group'
  parent: privateEndpointStorageAccount
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: dnsZoneId
        }
      }
    ]
  }
}

resource storageAccountSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACAShared
  name: 'storageAccountKey'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}

resource storageEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACAShared
  name: 'storageEndpoint'
  properties: {
    value: '${storageAccount.name}.${dnsZoneName}.${environment().suffixes.storage}'
  }
}

output storageAccountName string = storageAccount.name
output storageFileShareName string = fileShare.name
