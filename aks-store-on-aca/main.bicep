param environment string
param location string
param locationPrefix string
param subnets array
param tags object
param vnetIpRange string

/* Common resources that will be shared across services in the resource group */

module common 'modules/common.bicep' = {
  name: 'common'
  scope: resourceGroup()
  params: {
    environment: environment
    keyVaultName: keyvault.outputs.keyVaultName
    location: location 
    tags: tags
  }
  dependsOn: [vnet, keyvault]
}

/* Network resources, including private DNS zones with virtual network links for the private endpoints */
// TODO: look into iterating a list of DNS zones provided as parameter from the params file
module vnet 'modules/network.bicep' = {
  name: 'vnet'
  scope: resourceGroup()
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
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    dnsZoneKeyVault: vnet.outputs.dnsZoneKeyVaultId
    subnetId: vnet.outputs.acaSubnetId
  }
  dependsOn: [vnet]
}

resource keyVaultShared 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvault.outputs.keyVaultName
}

// AI-related services, like Azure OpenAI
module ai 'modules/ai.bicep' = {
  name: 'ai'
  scope: resourceGroup()
  params: {
    dnsZoneOpenAIId: vnet.outputs.dnsZoneOpenAIId
    keyVaultName: keyvault.outputs.keyVaultName
    location: location
    subnetId: vnet.outputs.acaSubnetId
    tags: tags    
  }
  dependsOn: [vnet, keyvault]
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup()
  params: {    
    dnsZoneId: vnet.outputs.dnsZoneFileId
    dnsZoneName: 'file'
    fileShareName: 'rabbitmq-data'
    keyVaultName: keyvault.outputs.keyVaultName
    location: location
    logAnalyticsWorkspaceId: common.outputs.logAnalyticsWorkspaceId
    subnetId: vnet.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [common, keyvault, vnet]
}

module acacommon 'modules/aca-common.bicep' = {
  name: 'aca-common'
  params: {
    appInsightsConnectionString: keyVaultShared.getSecret(common.outputs.appInsightsConnectionString)
    location: location
    logAnalyticsCustomerId: common.outputs.logAnalyticsCustomerId
    logAnalyticsKey: keyVaultShared.getSecret(common.outputs.logAnalyticsKey)
    //nsgName: vnet.outputs.nsgName
    storageFileShareName: storage.outputs.storageFileShareName
    storageName: storage.outputs.storageAccountName
    subnetId: vnet.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [common, storage, vnet]
}

module backend 'modules/aca-internal-apps.bicep' = {
  name: 'backend'
  scope: resourceGroup()
  params: {
    location: location    
    environmentId: acacommon.outputs.environmentId
    managedIdentityId: keyvault.outputs.managedIdentityId
    rabbitmqStorageName: acacommon.outputs.rabbitmqStorageName
    openAIApiEndpointKeyUri: ai.outputs.openAIEndpoint
    subnetIpRange: vnet.outputs.acaSubnetIpRange
    tags: tags
  }
  dependsOn: [acacommon, keyvault, storage]
}

module frontend 'modules/aca-public-apps.bicep' = {
  name: 'frontend'
  scope: resourceGroup()
  params: {
    //defaultDomain: acacommon.outputs.defaultDomain
    environmentId: acacommon.outputs.environmentId
    location: location
    makelineServiceUri: backend.outputs.makelineServiceUri
    managedIdentityId: keyvault.outputs.managedIdentityId
    orderServiceUri: backend.outputs.orderServiceUri
    productServiceUri: backend.outputs.productServiceUri
    tags: tags
  }
  dependsOn: [acacommon, keyvault, backend]
}

//@description('This is the frontend URL for your application')
//output url string = frontend.outputs.frontendurl
