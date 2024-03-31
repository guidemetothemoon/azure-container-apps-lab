using '../main.bicep'

param acaResourceGroupName = 'rg-aca-helloworld-neu-${environment}'
param environment = 'prod'
param location = 'northeurope'

param tags = {
  application: 'aca-revision-traffic-mgmt'
  environment: environment
}

param trafficDistribution = [
  {
    latestRevision: true
    weight: 100
  }
  /*{
    revisionName: ''
    weight: 50
  }*/
]
