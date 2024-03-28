param environmentId string
param managedIdentityId string
param openAIApiEndpointKeyUri string
param openAIApiKeyUri string
param location string
param tags object


resource container1 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'aca1'
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
      secrets: [
        {
          name: ''
          value: ''
        }
      ]
      ingress: { 
        external: true
        targetPort: 80
        transport: 'http'
        clientCertificateMode: 'accept'
      }
    }
    template: {
      containers: [
        {
          image: ''
          volumeMounts: [
            {
              mountPath: ''
              volumeName: ''
            }
          ]
          name: ''
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: ''
              value: ''
            }
            {
              name: ''
              value: ''
            }
          ]
          probes: [
            {
              type: 'liveness'
              httpGet: {
                path: '/'
                port: 80
              }
              initialDelaySeconds: 20
              periodSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'readiness'
              tcpSocket: {
                port: 80
              }
              initialDelaySeconds: 10
              periodSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'startup'
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
        maxReplicas: 3
      }
      volumes: [
        {
          name: ''
          storageType: 'Secret'
          secrets: [
            {
              secretRef: ''
              path: ''
            }
          ]
        }
      ]
    }
  }
}

resource container2 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'aca2'
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
      secrets: [
        {
          name: 'openai-api-uri'
          keyVaultUrl: openAIApiEndpointKeyUri
          identity: managedIdentityId
        }
        {
          name: 'openai-api-key'
          keyVaultUrl: openAIApiKeyUri
          identity: managedIdentityId
        }
        {
          name: 'mongodb-connection-uri'
          value: 'mongodb://mongodb'
        }
        {
          name: 'mongodb-port'
          value: '27017'
        }
      ]
      ingress: {    
        external: true //false
        targetPort: 8000
        transport: 'http'
        clientCertificateMode: 'accept'
      }
    }
    template: {
      containers: [
        {
          image: ''
          name: ''
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: ''
              value: ''
            }
            {
              name: ''
              value: ''
            }
          ]
          probes: [
            {
              type: 'liveness'
              httpGet: {
                path: '/docs'
                port: 8000
              }
              initialDelaySeconds: 30
              periodSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/docs'
                port: 8000
              }
              initialDelaySeconds: 30
              periodSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'startup'
              httpGet: {
                path: '/docs'
                port: 8000
              }
              initialDelaySeconds: 30
              periodSeconds: 3
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  tags: tags
}

