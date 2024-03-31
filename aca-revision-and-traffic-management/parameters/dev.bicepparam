using '../main.bicep'

param acaResourceGroupName = 'rg-aca-helloworld-neu-${environment}'
param environment = 'dev'
param location = 'northeurope'

param tags = {
  application: 'aca-revision-traffic-mgmt'
  environment: environment
}
param trafficDistribution = [
  {
    latestRevision: true
    weight: 50
  }
  {
    revisionName: 'aca-helloworld--f8u0hny'
    weight: 50
  }
]

// Command to get revision name: az containerapp revision list --name aca-helloworld --resource-group rg-aca-helloworld-neu-dev --query [0].name -o tsv
