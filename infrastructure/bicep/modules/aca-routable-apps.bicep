param acaEnvironmentId string
param backendContainerName string = 'backend-chaos-nyan-cat'
param frontendContainerName string = 'frontend-chaos-nyan-cat'
param managedIdentityId string
param location string
param tags object

var rawNginxConf = loadTextContent('default.conf')
var nginxConf = replace(rawNginxConf, 'BACKEND_FQDN', backend.name)
//var nginxConf = replace(rawNginxConf, 'BACKEND_FQDN', backend.properties.latestRevisionFqdn)

resource frontend 'Microsoft.App/containerApps@2023-05-01' = {
  name: frontendContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      secrets: [
        {
          name: 'nginx-conf'
          value: nginxConf
        }
      ]
      ingress: { 
        external: true
        targetPort: 80
        transport: 'http'
        clientCertificateMode: 'require'
      }
    }
    template: {
      containers: [
        {
          image: 'guidemetothemoon/kube-nyan-cat:latest'
          volumeMounts: [
            {
              mountPath: '/etc/nginx/conf.d/'
              volumeName: 'nginx-conf'
            }
          ]
          name: frontendContainerName
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
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
        maxReplicas: 2
      }
      volumes: [
        {
          name: 'nginx-conf'
          storageType: 'Secret'
          secrets: [
            {
              secretRef: 'nginx-conf'
              path: 'default.conf'
            }
          ]
        }
      ]
    }
  }

  tags: tags
}

resource backend 'Microsoft.App/containerApps@2023-05-01' = {
  name: backendContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      ingress: {    
        external: false
        targetPort: 80
        transport: 'http'
        allowInsecure: true
        clientCertificateMode: 'require'
      }
    }
    template: {
      containers: [
        {
          image: 'guidemetothemoon/kube-nyan-cat:latest'
          name: backendContainerName
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
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
        maxReplicas: 2
      }
    }
  }
  
  tags: tags
}
