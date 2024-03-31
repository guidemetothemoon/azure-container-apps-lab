targetScope='subscription'

param acaResourceGroupName string
param commonResourceGroupName string
param commonKeyVaultName string
param environment string
param location string
param locationPrefix string
param openAILocation string
param subnets array
param tags object
param vnetIpRange string

resource keyVaultCommon 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  scope: resourceGroup(commonResourceGroupName)
  name: commonKeyVaultName
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: acaResourceGroupName
  location: location
}

/* Common resources that will be shared across services in the resource group */

module common 'modules/common.bicep' = {
  name: 'common'
  scope: rg
  params: {
    environment: environment
    location: location 
    tags: tags
  }
}

/* Network resources, including private DNS zones with virtual network links for the private endpoints */
// TODO: look into iterating a list of DNS zones provided as parameter from the params file
module vnet 'modules/network.bicep' = {
  name: 'vnet'
  scope: rg
  params: { 
    dnsZoneNameFile: 'privatelink.file.${az.environment().suffixes.storage}'
    dnsZoneNameKeyVault: 'privatelink.vaultcore.azure.net'
    dnsZoneNameOpenAI: 'privatelink.openai.azure.com'
    environment: environment
    location: location
    locationPrefix: locationPrefix
    subnets: subnets
    tags: tags
    vnetIpRange: vnetIpRange
  }
}

/* Azure Key Vault resources, including respective access control and private endpoint configuration */
module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    dnsZoneKeyVault: vnet.outputs.dnsZoneKeyVaultId
    location: location
    managedIdentityName: common.outputs.managedIdentityName
    subnetId: vnet.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [vnet]
}

module azuremonitor 'modules/azure-monitor.bicep' = {
  name: 'azuremonitor'
  scope: rg
  params: {
    environment: environment
    keyVaultName: keyvault.outputs.keyVaultName
    location: location 
    tags: tags
  }
  dependsOn: [vnet, keyvault]
}

resource keyVaultACAShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvault.outputs.keyVaultName
  scope: rg
}

// AI-related services, like Azure OpenAI
module ai 'modules/ai.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    dnsZoneOpenAIId: vnet.outputs.dnsZoneOpenAIId
    keyVaultName: keyvault.outputs.keyVaultName
    location: location
    managedIdentityId: common.outputs.managedIdentityId
    openAILocation: openAILocation
    subnetId: vnet.outputs.acaSubnetId
    tags: tags    
  }
  dependsOn: [vnet, keyvault]
}

module acacommon 'modules/aca-common.bicep' = {
  name: 'aca-common'
  scope: rg
  params: {
    appInsightsConnectionString: keyVaultACAShared.getSecret(azuremonitor.outputs.appInsightsConnectionString)
    location: location
    logAnalyticsCustomerId: azuremonitor.outputs.logAnalyticsCustomerId
    logAnalyticsKey: keyVaultACAShared.getSecret(azuremonitor.outputs.logAnalyticsKey)
    managedIdentityId: common.outputs.managedIdentityId
    nsgName: vnet.outputs.nsgName
    subnetId: vnet.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [common, keyvault, vnet]
}

module backend 'modules/aca-internal-apps.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    location: location    
    environmentId: acacommon.outputs.environmentId
    openAIEndpoint: keyVaultACAShared.getSecret('cogaEndpoint')
    queueUsername: keyVaultCommon.getSecret('queue-username')
    queuePass: keyVaultCommon.getSecret('queue-password')
    subnetIpRange: vnet.outputs.acaSubnetIpRange
    tags: tags
  }
  dependsOn: [acacommon, keyvault]
}

module frontend 'modules/aca-public-apps.bicep' = {
  name: 'frontend'
  scope: rg
  params: {
    environmentId: acacommon.outputs.environmentId
    location: location
    makelineServiceUri: backend.outputs.makelineServiceUri
    managedIdentityId: common.outputs.managedIdentityId
    orderServiceUri: backend.outputs.orderServiceUri
    productServiceUri: backend.outputs.productServiceUri
    tags: tags
  }
  dependsOn: [acacommon, keyvault, backend]
}

@description('URL for store application')
output storeUrl string = frontend.outputs.storeFrontUri

@description('URL for store admin application')
output storeAdminUrl string = frontend.outputs.storeAdminUri
