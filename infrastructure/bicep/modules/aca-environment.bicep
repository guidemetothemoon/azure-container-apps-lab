param acaEnvironmentName string
param acaSubnetId string
param location string
param logAnalyticsCustomerId string
param tags object

@secure()
param logAnalyticsPrimarySharedKey string

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  location: location
  name: acaEnvironmentName
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsPrimarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
    }
  }
  tags: tags
}

output environmentId string = containerAppEnvironment.id
