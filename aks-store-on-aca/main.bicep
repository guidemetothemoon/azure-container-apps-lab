targetScope='subscription'

@description('Resource group name where Azure Container Apps resources will be provisioned')
param acaResourceGroupName string

@description('Resource group name where resources that are shared across different resource group are provisioned')
param commonResourceGroupName string

@description('Name of the common Azure Key Vault that contains secrets that can\'t be uploaded as part of the Bicep code')
param commonKeyVaultName string

@description('Environment name (dev, test, prod)')
param environment string

@description('Location where resources will be provisioned')
param location string

@description('Prefix for the location name (e.g. "neu" for "northeurope")')
param locationPrefix string

@description('Location where Azure OpenAI resources will be provisioned')
param openAILocation string

@description('Subnets for the virtual network used by the Azure Container Apps resources')
param subnets array

@description('Tags to be applied to all resources in this deployment')
param tags object

@description('IP range for the virtual network that will be utilized by the Azure Container Apps resources')
param vnetIpRange string

@description('List of Azure Monitor Private Link Scope (AMPLS) private DNS zones that will be used by the private endpoints in the deployment')
var amplsPrivateDnsZones = [  
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.blob.${az.environment().name}'
]

@description('List of non-AMPLS private DNS zones that will be used by the private endpoints in the deployment')
var otherPrivateDnsZones = [
  'privatelink.vaultcore.azure.net'
  'privatelink.openai.azure.com'
]

resource keyVaultCommon 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  scope: resourceGroup(commonResourceGroupName)
  name: commonKeyVaultName
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: acaResourceGroupName
  location: location
}

@description('Module that provisions common resources that will be re-used by other resources in the deployment, like managed identities')
module common 'modules/common.bicep' = {
  name: 'common-resources'
  scope: rg
  params: {
    environment: environment
    location: location 
    tags: tags
  }
}

@description('Module that provisions network-related resources, like virtual network, subnets and network security groups')
module network 'modules/network.bicep' = {
  name: 'network-resources'
  scope: rg
  params: {
    environment: environment
    location: location
    locationPrefix: locationPrefix
    subnets: subnets
    tags: tags
    vnetIpRange: vnetIpRange
  }
}

@description('Module that provisions DNS-related resources, like private DNS zones')
module dns 'modules/dns.bicep' = {
  name: 'dns-resources'
  scope: rg
  params: {
    privateDnsZones: union(amplsPrivateDnsZones, otherPrivateDnsZones)
    tags: tags
  }
}

@description('Module that provisions virtual network links for mapping respective virtual network resources with the private DNS zones')
module vnet_links 'modules/virtual-network-links.bicep' = [for (zone, i) in union(amplsPrivateDnsZones, otherPrivateDnsZones): {
  name: '${zone}-vnetlink-deploy'
  scope: rg
  params: {
    vnetId: network.outputs.vnetId
    dnsZoneName: zone
    tags: tags
  }
  dependsOn: [dns]
}]

@description('Module that provisions Azure Key Vault that will be used by Azure Container Apps, with enabled RBAC and restricted access configuration, including access only through private endpoint.')
module kv 'modules/keyvault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    keyVaultDnsZoneName: otherPrivateDnsZones[0]
    location: location
    managedIdentityName: common.outputs.managedIdentityName
    subnetId: network.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [dns]
}

@description('Module that provisions Azure Monitor resources, like Log Analytics workspace and Application Insights, including Azure Monitor Private Link Scope (AMPLS) for secure access to observability resources.')
module azure_monitor 'modules/azure-monitor.bicep' = {
  name: 'azure-monitor'
  scope: rg
  params: {
    amplsPrivateDnsZones: amplsPrivateDnsZones
    environment: environment
    keyVaultName: kv.outputs.keyVaultName
    location: location
    locationPrefix: locationPrefix
    managedIdentityId: common.outputs.managedIdentityId
    subnetId: network.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [dns, vnet_links]
}

resource keyVaultACA 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: kv.outputs.keyVaultName
  scope: rg
}

@description('Module that provisions AI-related resources, like Azure OpenAI with respective model deployments, with restricted access configuration, like resource access only through private endpoint.')
module ai 'modules/ai.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    openAIDnsZoneName: otherPrivateDnsZones[1]
    keyVaultName: kv.outputs.keyVaultName
    location: location
    managedIdentityId: common.outputs.managedIdentityId
    openAILocation: openAILocation
    subnetId: network.outputs.acaSubnetId
    tags: tags
  }
  dependsOn: [dns]
}

@description('Module that provisions common overall resources for Azure Container Apps, like Azure Container Apps environment, with restricted access configuration, like resource access only for defined subnets and ports.')
module aca_common 'modules/aca-common.bicep' = {
  name: 'aca-common'
  scope: rg
  params: {
    location: location
    logAnalyticsCustomerId: azure_monitor.outputs.logAnalyticsCustomerId
    logAnalyticsKey: keyVaultACA.getSecret(azure_monitor.outputs.logAnalyticsKey)
    managedIdentityId: common.outputs.managedIdentityId
    nsgName: network.outputs.nsgName
    subnetId: network.outputs.acaSubnetId
    tags: tags
  }
}

@description('Module that provisions internal applications as Azure Container Apps.')
module internal_apps 'modules/aca-internal-apps.bicep' = {
  name: 'internal-apps'
  scope: rg
  params: {
    environmentId: aca_common.outputs.environmentId
    location: location
    managedIdentityId: common.outputs.managedIdentityId  
    openAIDeploymentName: ai.outputs.openAIDeploymentName
    openAIEndpointSecretUri: ai.outputs.openAIEndpointSecretUri
    openAIKeySecretUri: ai.outputs.openAIKeySecretUri
    queueUsername: keyVaultCommon.getSecret('queue-username')
    queuePass: keyVaultCommon.getSecret('queue-password')
    subnetIpRange: network.outputs.acaSubnetIpRange
    tags: tags
  }
}

@description('Module that provisions publicly accessible applications as Azure Container Apps.')
module public_apps 'modules/aca-public-apps.bicep' = {
  name: 'public-apps'
  scope: rg
  params: {
    environmentId: aca_common.outputs.environmentId
    location: location
    makelineServiceUri: internal_apps.outputs.makelineServiceUri
    managedIdentityId: common.outputs.managedIdentityId
    orderServiceUri: internal_apps.outputs.orderServiceUri
    productServiceUri: internal_apps.outputs.productServiceUri
    storeAdminAuthClientId: keyVaultCommon.getSecret('store-admin-auth-client-id')
    storeAdminAuthClientSecret: keyVaultCommon.getSecret('store-admin-auth-client-secret')
    storeAdminAuthTenantId: keyVaultCommon.getSecret('store-admin-auth-tenant-id')
    tags: tags
  }
}

@description('URL for accessing store application')
output storeUrl string = public_apps.outputs.storeFrontUri

@description('URL for accessing store admin application')
output storeAdminUrl string = public_apps.outputs.storeAdminUri
