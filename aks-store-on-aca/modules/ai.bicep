param openAIDnsZoneName string
param keyVaultName string
param location string
param managedIdentityId string
param openAILocation string
param subnetId string
param tags object

var cognitiveAccountName = 'coga-${uniqueString('cognitive', resourceGroup().id)}'

resource keyVaultACA 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource openAIDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: openAIDnsZoneName
}

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: cognitiveAccountName
  location: openAILocation
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    customSubDomainName: cognitiveAccountName
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: false
    disableLocalAuth: false
  }
  tags: tags
}

resource cognitiveAccountDeploymentGpt35Turbo 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: cognitiveAccount
  name: 'gpt-35-turbo'
  sku: {
    name: 'Standard'
    capacity: 240
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0301'
    }
  }
}

resource privateEndpointCognitiveAccount 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-${cognitiveAccountName}'
  location: location  
  properties: {
    customNetworkInterfaceName: '${cognitiveAccountName}-nic-deluxe'
    privateLinkServiceConnections: [
      {
        name: 'psc-${cognitiveAccountName}'
        properties: {
          privateLinkServiceId: cognitiveAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  tags: tags
}

resource cogaPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  name: '${privateEndpointCognitiveAccount.name}-dns-zone-group'
  parent: privateEndpointCognitiveAccount
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: openAIDnsZone.id
        }
      }
    ]
  }
}

resource openAIKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACA
  name: 'cogaKey'
  properties: {
    value: cognitiveAccount.listKeys().key1
  }
}

resource cognitiveAccountEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACA
  name: 'cogaEndpoint'
  properties: {
    value: cognitiveAccount.properties.endpoint
  }
}

output openAIDeploymentName string = cognitiveAccountDeploymentGpt35Turbo.name
