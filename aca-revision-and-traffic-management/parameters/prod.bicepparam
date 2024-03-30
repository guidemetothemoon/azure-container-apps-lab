using '../main.bicep'

param acaResourceGroupName = 'rg-aca-aci-${locationPrefix}-${environment}'
param environment = 'prod'
param location = 'northeurope'
param locationPrefix = 'neu'

param tags = {
  application: 'aca-win-aci'
  environment: environment
}
