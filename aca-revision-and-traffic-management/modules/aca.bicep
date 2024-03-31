param environmentId string
param location string
param managedIdentityId string
param tags object
param trafficDistribution array

resource helloworld 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'aca-helloworld'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: { 
        external: true
        targetPort: 80
        transport: 'http'
        clientCertificateMode: 'accept'
        traffic: trafficDistribution
      }
      activeRevisionsMode: 'Multiple'
      maxInactiveRevisions: 2
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/aks-helloworld:v1'
          name: 'aca-helloworld'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'TITLE'
              value: 'Hello World from Azure Container Apps (ACA) - V2!'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 80
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/'
                port: 80
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
}

output helloWorldAppUri string = 'https://${helloworld.properties.configuration.ingress.fqdn}'
