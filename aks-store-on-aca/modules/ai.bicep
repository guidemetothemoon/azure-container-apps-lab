param dnsZoneOpenAIId string
param keyVaultName string
param location string
param subnetId string
param tags object
var cognitiveAccountName = 'coga-${uniqueString('cognitive', resourceGroup().id)}'

resource keyVaultShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: cognitiveAccountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  identity: {
    type: 'None'
  }
  properties: {
    customSubDomainName: cognitiveAccountName
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: false
    disableLocalAuth: false
    dynamicThrottlingEnabled: false
  }
  tags: tags
}

resource cognitiveAccountDeploymentGpt35Turbo 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: cognitiveAccount
  name: 'gpt-4-32k'
  sku: {
    name: 'Standard'
    capacity: 80
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
  parent: keyVaultShared
  name: 'cogaKey'
  properties: {
    value: cognitiveAccount.listKeys().key1
  }
}

resource cognitiveAccountEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultShared
  name: 'cogaEndpoint'
  properties: {
    value: cognitiveAccount.properties.endpoint
  }
}

output openAIEndpoint string = cognitiveAccountEndpoint.properties.secretUri
output openAIKey string = openAIKeySecret.properties.secretUri
