using '../main.bicep'

param acaResourceGroupName = 'rg-aca-${locationPrefix}-${environment}'
param environment = 'dev'
param openAILocation = 'francecentral'
param location = 'northeurope'
param locationPrefix = 'neu'

param tags = {
  application: 'aca-store'
  environment: environment
}

param vnetIpRange = '10.0.0.0/21'

param subnets = [
  {
    name: 'snet-aca-${environment}'
    subnetPrefix: '10.0.0.0/23'
  }
]

param commonResourceGroupName = 'kris-chief-rg'
param commonKeyVaultName = 'kv-neu-common'
