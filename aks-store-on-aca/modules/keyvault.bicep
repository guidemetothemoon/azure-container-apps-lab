param dnsZoneKeyVault string
param location string
param managedIdentityName string
param subnetId string
param tags object
param tenantId string = subscription().tenantId


resource keyVaultSecretsOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: 'kv-${uniqueString('keyvault', resourceGroup().id)}'
  location: location
  properties: {
    enabledForTemplateDeployment: true
    enablePurgeProtection: false // for production you would want it to be enabled, i.e. set to 'true'
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    tenantId: tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          id: subnetId
        }
      ]
    }
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
  tags: tags
}

resource keyVaultroleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(keyVault.id, managedIdentity.id, keyVaultSecretsOfficerRoleDefinition.id)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsOfficerRoleDefinition.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource privateEndpointKeyVault 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-${keyVault.name}'
  location: location  
  properties: {
    customNetworkInterfaceName: '${keyVault.name}-nic-deluxe'
    privateLinkServiceConnections: [
      {
        name: 'psc-${keyVault.name}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
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

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  name: '${privateEndpointKeyVault.name}-dns-zone-group'
  parent: privateEndpointKeyVault
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: dnsZoneKeyVault
        }
      }
    ]
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
