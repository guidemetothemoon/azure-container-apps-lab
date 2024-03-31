using '../main.bicep'

param acaResourceGroupName = 'rg-aca-helloworld-${locationPrefix}-${environment}'
param environment = 'dev'
param location = 'northeurope'
param locationPrefix = 'neu'

param tags = {
  application: 'aca-revision-traffic-mgmt'
  environment: environment
}

