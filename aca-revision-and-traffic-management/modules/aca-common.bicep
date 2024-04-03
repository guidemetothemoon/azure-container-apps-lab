param location string
param logAnalyticsWorkspaceId string
param managedIdentityId string
param tags object

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: 'cae-aca-helloworld'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    appLogsConfiguration: {
      /* In this demo Azure Monitor is configured as ACA logs destination: https://learn.microsoft.com/en-us/azure/container-apps/log-options
       * If you would like to see how 'Log Analytics' option is configured, please check out ./aks-store-on-aca/modules/aca-common.bicep file
      */
      destination: 'azure-monitor'
    }
  }
  tags: tags
}

@description('Diagnostic setting for the ACA environment that\'s required when Azure Monitor is configured as logs destination.')
resource acaEnvironmentDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: containerAppsEnvironment.name
  scope: containerAppsEnvironment
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output environmentId string = containerAppsEnvironment.id
