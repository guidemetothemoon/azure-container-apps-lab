param environmentId string
param location string
param makelineServiceUri string
param managedIdentityId string
param orderServiceUri string
param productServiceUri string
param tags object

resource storefront 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'store-front'
  location: location
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
        exposedPort: 80
        targetPort: 8080
        transport: 'http'
        clientCertificateMode: 'accept'
      }
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/store-front:latest'
          name: 'store-front'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: 'VUE_APP_ORDER_SERVICE_URL'
              value: orderServiceUri
            }
            {
              name: 'VUE_APP_PRODUCT_SERVICE_URL'
              value: productServiceUri
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 5
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

resource storeadmin 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'store-admin'
  location: location
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
        external: true //false
        exposedPort: 80
        targetPort: 8081
        transport: 'http'
        clientCertificateMode: 'accept'
      }
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/store-admin:latest'
          name: 'store-admin'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: 'VUE_APP_MAKELINE_SERVICE_URL'
              value: makelineServiceUri
            }
            {
              name: 'VUE_APP_PRODUCT_SERVICE_URL'
              value: productServiceUri
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8081
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8081
              }
              initialDelaySeconds: 3
              periodSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8081
              }
              initialDelaySeconds: 5
              periodSeconds: 5
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
  tags: tags
}
