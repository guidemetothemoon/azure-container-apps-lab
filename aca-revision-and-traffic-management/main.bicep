// TODO
targetScope='subscription'

param acaResourceGroupName string
param environment string
param location string
param locationPrefix string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: acaResourceGroupName
  location: location
}

module common 'modules/common.bicep' = {
  name: 'common'
  scope: rg
  params: {
    environment: environment
    location: location 
    tags: tags
  }
}

module acaenvironment 'modules/aca-environment.bicep' = {
  name: 'aca-environment'
  scope: rg
  params: {
    location: location
    managedIdentityId: common.outputs.managedIdentityId
    tags: tags
  }
  dependsOn: [common]
}

module aca 'modules/aca.bicep' = {
  name: 'aca'
  scope: rg
  params: {
    environmentId: acaenvironment.outputs.environmentId
    location: location
    managedIdentityId: common.outputs.managedIdentityId
    tags: tags
  }
  dependsOn: [acaenvironment]
}

@description('URL for store application')
output storeUrl string = aca.outputs.helloWorldAppUri
