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

// Command to get revision names: az containerapp revision list --name aca-helloworld --resource-group rg-aca-helloworld-neu-dev --query [].name -o tsv
