param environmentId string
param location string
param managedIdentityId string
param openAIApiEndpointKeyUri string
param rabbitmqStorageName string
param subnetIpRange string
param tags object

// MongoDB instance for persisted data

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
          image: 'mcr.microsoft.com/mirror/docker/library/mongo:4.2'
          name: 'mongodb'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          //command: [
          //  'mongod'
          //  '--dbpath'
          //  '/data/mongoaz'
          //  '--bind_ip_all'
          //]
          probes: [
            {
              type: 'liveness'              
              tcpSocket: {
                port: 27017
              }
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        //maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource rabbitmq 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'rabbitmq'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 5672
        transport: 'tcp'
        additionalPortMappings: [
          {
            external: false
            targetPort: 15672
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
      secrets: [
        {
          name: 'queue-username'
          keyVaultUrl: 'foo' // TODO
          identity: managedIdentityId
        }
        {
          name: 'queue-password'
          keyVaultUrl: 'bar' // TODO
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/mirror/docker/library/rabbitmq:3.10-management-alpine'
          name: 'rabbitmq'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'RABBITMQ_DEFAULT_USER'
              secretRef: 'queue-username'
            }
            {
              name: 'RABBITMQ_DEFAULT_PASS'
              secretRef: 'queue-password'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'rabbitmq-enabled-plugins'
              mountPath: '/etc/rabbitmq/enabled_plugins'
              subPath: 'enabled_plugins'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
      volumes: [mongodb
        {
          name: 'rabbitmq-enabled-plugins'
          storageType: 'AzureFile'
          storageName: rabbitmqStorageName
        }
      ]
    }
  }  
  tags: tags
}

resource orderservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'order-service'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 3000
        transport: 'http'
        ipSecurityRestrictions: [
          {
            name: 'AllowSnet'
            description: 'Allow access from main subnet'
            action: 'Allow'
            ipAddressRange:  subnetIpRange
          }
        ]
      }
      secrets: [
        {
          name: 'queue-username'
          keyVaultUrl: 'foo' // TODO
          identity: managedIdentityId
        }
        {
          name: 'queue-password'
          keyVaultUrl: 'bar' // TODO
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/order-service:latest'
          name: 'order-service'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ORDER_QUEUE_HOSTNAME'
              value: 'rabbitmq'
            }
            {
              name: 'ORDER_QUEUE_PORT'
              value: '5672'
            }
            {
              name: 'ORDER_QUEUE_USERNAME'
              secretRef: 'queue-username'
            }
            {
              name: 'ORDER_QUEUE_PASSWORD'
              secretRef: 'queue-password'
            }
            {
              name: 'ORDER_QUEUE_NAME'
              value: 'orders'
            }
            {
              name: 'FASTIFY_ADDRESS'
              value: '0.0.0.0'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 3
              periodSeconds: 5
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 3
              periodSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 15
              periodSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      initContainers: [
        {
          name: 'wait-for-rabbitmq'
          image: 'busybox'
          command: [
            'sh'
            '-c'
            'until nc -zv rabbitmq 5672; do echo waiting for rabbitmq; sleep 2; done;'
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }  
  tags: tags
}

resource makelineservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'makeline-service'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 3001
        transport: 'http'
        ipSecurityRestrictions: [
          {
            name: 'AllowSnet'
            description: 'Allow access from main subnet'
            action: 'Allow'
            ipAddressRange:  subnetIpRange
          }
        ]
      }
      secrets: [
        {
          name: 'order-queue-username'
          keyVaultUrl: 'foo' // TODO
          identity: managedIdentityId
        }
        {
          name: 'order-queue-password'
          keyVaultUrl: 'bar' // TODO
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/makeline-service:latest'
          name: 'makeline-service'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ORDER_QUEUE_URI'
              value: 'amqp://rabbitmq:5672'
            }
            {
              name: 'ORDER_QUEUE_USERNAME'
              secretRef: 'order-queue-username'
            }
            {
              name: 'ORDER_QUEUE_PASSWORD'
              secretRef: 'order-queue-password'
            }
            {
              name: 'ORDER_QUEUE_NAME'
              value: 'orders'
            }
            {
              name: 'ORDER_DB_URI'
              value: 'mongodb://mongodb:27017'
            }
            {
              name: 'ORDER_DB_NAME'
              value: 'orderdb'
            }
            {
              name: 'ORDER_DB_COLLECTION_NAME'
              value: 'orders'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3001
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3001
              }
              initialDelaySeconds: 3
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

resource productservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'product-service'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 3002
        transport: 'http'
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
          image: 'ghcr.io/azure-samples/aks-store-demo/product-service:latest'
          name: 'product-service'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AI_SERVICE_URL'
              value: openAIApiEndpointKeyUri
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3002
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3002
              }
              initialDelaySeconds: 3
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

resource virtualcustomer 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'virtual-customer'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/virtual-customer:latest'
          name: 'virtual-customer'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ORDER_SERVICE_URL'
              value: orderservice.properties.configuration.ingress.fqdn
            }
            {
              name: 'ORDERS_PER_HOUR'
              value: '100'
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

resource virtualworker 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'virtual-worker'
  location: location
  properties: {
    managedEnvironmentId: environmentId
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/virtual-worker:latest'
          name: 'virtual-worker'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'MAKELINE_SERVICE_URL'
              value: makelineservice.properties.configuration.ingress.fqdn
            }
            {
              name: 'ORDERS_PER_HOUR'
              value: '100'
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

output makelineServiceUri string = makelineservice.properties.configuration.ingress.fqdn
output orderServiceUri string =  orderservice.properties.configuration.ingress.fqdn
output productServiceUri string = productservice.properties.configuration.ingress.fqdn
