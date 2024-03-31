param dnsZoneOpenAIId string
param keyVaultName string
param location string
param managedIdentityId string
param openAILocation string
param subnetId string
param tags object

var cognitiveAccountName = 'coga-${uniqueString('cognitive', resourceGroup().id)}'

resource keyVaultACAShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
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

resource cognitiveAccountDeploymentGpt432k 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: cognitiveAccount
  name: 'gpt-4-32k'
  sku: {
    name: 'Standard'
    capacity: 60
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4-32k'
      version: '0613'
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
          privateDnsZoneId: dnsZoneOpenAIId
        }
      }
    ]
  }
}

resource openAIKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACAShared
  name: 'cogaKey'
  properties: {
    value: cognitiveAccount.listKeys().key1
  }
}

resource cognitiveAccountEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultACAShared
  name: 'cogaEndpoint'
  properties: {
    value: cognitiveAccount.properties.endpoint
  }
}

output openAIEndpoint string = cognitiveAccountEndpoint.properties.secretUri
output openAIKey string = openAIKeySecret.properties.secretUri
