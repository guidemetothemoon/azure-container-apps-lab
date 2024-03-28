param subnetIpRange string
param environmentId string
param location string
param mongoDbStorageName string
param tags object

resource container3 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'aca3'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {      
        external: false
        targetPort: 6379
        transport: 'tcp'
        exposedPort: 6379
        additionalPortMappings: [
          {
            external: false
            targetPort: 8001
            exposedPort: 8001
          }
        ]
        ipSecurityRestrictions: [
          {
            name: 'AllowSnet'
            description: 'Allow access from main subnet'
            action: 'Allow'
            ipAddressRange:  subnetIpRange
          }
        ]
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
          probes: [
            {
              type: 'liveness'
              tcpSocket: {
                port: 6379
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 2
              failureThreshold: 3
            }
            {
              type: 'readiness'
              tcpSocket: {
                port: 6379
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 2
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

// Mounted Azure File storage as a volume

resource mongodb 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'mongodb'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 27017
        transport: 'tcp'
        additionalPortMappings: [
          {
            external: false
            targetPort: 8000
          }
        ]
        ipSecurityRestrictions: [
          {
            name: 'AllowSnet'
            description: 'Allow access from main subnet'
            action: 'Allow'
            ipAddressRange:  subnetIpRange
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: 'mongo:latest'
          name: 'mongodb'
          resources: {
            cpu: json('2.0')
            memory: '4.0Gi'
          }
          command: [
            'mongod'
            '--dbpath'
            '/data/mongoaz'
            '--bind_ip_all'
          ]
          volumeMounts: [
            {              
              volumeName: 'mongodb-data'
              mountPath: '/data/mongoaz'
            }
          ]
          // probes: [
          //   {
          //     type: 'liveness'
          //     tcpSocket: {
          //       port: 27017
          //     }
          //     initialDelaySeconds: 60
          //     periodSeconds: 10
          //     timeoutSeconds: 2
          //     failureThreshold: 3
          //   }
          //   {
          //     type: 'readiness'
          //     tcpSocket: {
          //       port: 27017
          //     }
          //     initialDelaySeconds: 60
          //     periodSeconds: 10
          //     timeoutSeconds: 2
          //     failureThreshold: 3
          //   }
          // ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'mongodb-data'
          storageType: 'AzureFile'
          storageName: mongoDbStorageName
        }
      ]
    }
  }  
  tags: tags
}

output mongoDBFqdn string = mongodb.properties.configuration.ingress.fqdn
