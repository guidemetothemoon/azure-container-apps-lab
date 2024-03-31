param location string
param logAnalyticsCustomerId string
param nsgName string
param subnetId string
param tags object

@secure()
param appInsightsConnectionString string

@secure()
param logAnalyticsKey string



resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: 'cae-aca-store'
  location: location
  properties: {
    appInsightsConfiguration: {
      connectionString: appInsightsConnectionString
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
    }
  }
  tags: tags
}


resource containerAppsInboundNsgRule 'Microsoft.Network/networkSecurityGroups/securityRules@2023-05-01' = {  
  name: '${nsgName}/AllowInternet443FrontendInbound'  
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: containerAppsEnvironment.properties.staticIp
    access: 'Allow'
    priority: 100
    direction: 'Inbound'
  }
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output environmentId string = containerAppsEnvironment.id