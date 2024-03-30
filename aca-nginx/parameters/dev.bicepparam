using '../main.bicep'

param acaResourceGroupName = 'rg-aca-nginx-${locationPrefix}-${environment}'
param environment = 'dev'
param location = 'northeurope'
param locationPrefix = 'neu'

param tags = {
  application: 'aca-nginx'
  environment: environment
}

