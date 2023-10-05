param location string = resourceGroup().location

param tags object = {
  app: 'chaos-nyan-cat'
  environment: 'development'
  project: 'azure-container-apps-lab'
}

var vnetName = 'aca-chaos-nyan-cat'

module vnet 'modules/network.bicep' = {
  name: 'vnet'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    vnetAddressSpace: '172.16.0.0/21'
    vnetName: vnetName    
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
  }
}

module common 'modules/common.bicep' = {
  name: 'common'
  scope: resourceGroup()
  params: {
    keyVaultName: keyvault.outputs.keyVaultName
    location: location   
    tags: tags
  }
  dependsOn: [keyvault]
}

resource commonKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvault.outputs.keyVaultName
}

module acaenvironment 'modules/aca-environment.bicep' = {
  name: 'aca-environment'
  params: {
    acaEnvironmentName: 'aca-environment'
    acaSubnetId: vnet.outputs.acaSubnetId
    location: location
    logAnalyticsCustomerId: common.outputs.logAnalyticsCustomerId
    logAnalyticsPrimarySharedKey: commonKeyVault.getSecret(common.outputs.logAnalyticsPrimarySharedKey)    
    tags: tags
  }
  dependsOn: [common, vnet]
}

module aca 'modules/aca-routable-apps.bicep' = {
  name: 'aca'
  scope: resourceGroup()
  params: {
    acaEnvironmentId: acaenvironment.outputs.environmentId
    location: location
    managedIdentityId: keyvault.outputs.managedIdentityId
    tags: tags
  }
  dependsOn: [acaenvironment]
}
