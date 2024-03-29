targetScope='subscription'

param acaResourceGroupName string
param commonResourceGroupName string
//param commonKeyVaultManagedIdentityName string
param commonKeyVaultName string
param environment string
param location string
param locationPrefix string
param openAILocation string
param subnets array
param tags object
param vnetIpRange string

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
    location: location
    tags: tags
    dnsZoneKeyVault: vnet.outputs.dnsZoneKeyVaultId
    subnetId: vnet.outputs.acaSubnetId
  }
  dependsOn: [vnet]
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
    openAILocation: openAILocation
    subnetId: vnet.outputs.acaSubnetId
    tags: tags    
  }
  dependsOn: [vnet, keyvault]
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
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
  scope: rg
  params: {
    appInsightsConnectionString: keyVaultACAShared.getSecret(common.outputs.appInsightsConnectionString)
    location: location
    logAnalyticsCustomerId: common.outputs.logAnalyticsCustomerId
    logAnalyticsKey: keyVaultACAShared.getSecret(common.outputs.logAnalyticsKey)
    //nsgName: vnet.outputs.nsgName
    //storageFileShareName: storage.outputs.storageFileShareName
    //storageName: storage.outputs.storageAccountName
    subnetId: vnet.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [common, keyvault, storage, vnet]
}

resource keyVaultCommon 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  scope: resourceGroup(commonResourceGroupName)
  name: commonKeyVaultName
}

//resource keyVaultCommonManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
//  scope: resourceGroup(commonResourceGroupName)
//  name: commonKeyVaultManagedIdentityName
//}

module backend 'modules/aca-internal-apps.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    location: location    
    environmentId: acacommon.outputs.environmentId
    //rabbitmqStorageName: acacommon.outputs.rabbitmqStorageName
    //managedIdentityId: keyvault.outputs.managedIdentityId
    openAIEndpoint: keyVaultACAShared.getSecret('cogaEndpoint')
    queueUsername: keyVaultCommon.getSecret('queue-username')
    queuePass: keyVaultCommon.getSecret('queue-password')
    subnetIpRange: vnet.outputs.acaSubnetIpRange
    tags: tags
  }
  dependsOn: [acacommon, keyvault, storage]
}

module frontend 'modules/aca-public-apps.bicep' = {
  name: 'frontend'
  scope: rg
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

@description('URL for store application')
output storeUrl string = frontend.outputs.storeFrontUri

@description('URL for store admin application')
output storeAdminUrl string = frontend.outputs.storeAdminUri
