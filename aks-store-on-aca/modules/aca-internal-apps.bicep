param environmentId string
param location string
param managedIdentityId string
param openAIDeploymentName string
param openAIEndpointSecretUri string
param openAIKeySecretUri string
param subnetIpRange string
param tags object

@secure()
param queueUsername string

@secure()
param queuePass string

/* ConfigMap isn't supported in Azure Container Apps, but an alternative way is to mount a file containing the needed information to the RabbitMQ container app. */
var rabbitmqPluginsConf = loadTextContent('rabbitmq_enabled_plugins')

resource mongodb 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'mongodb'
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource rabbitmq 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'rabbitmq'
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
          name: 'rabbitmq-enabled-plugins'
          value: rabbitmqPluginsConf
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
              value: queueUsername
            }
            {
              name: 'RABBITMQ_DEFAULT_PASS'
              value: queuePass
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
        maxReplicas: 3
      }
      volumes: [
        {
          name: 'rabbitmq-enabled-plugins'
          storageType: 'Secret'
          secrets: [
            {
              secretRef: 'rabbitmq-enabled-plugins'
              path: 'enabled_plugins'
            }
          ]
        }
      ]
    }
  }  
  tags: tags
}

resource orderservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'order-service'
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
        external: false
        targetPort: 3000
        transport: 'http'
        allowInsecure: true // required for this service due to limitations in the original application
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
              value: queueUsername
            }
            {
              name: 'ORDER_QUEUE_PASSWORD'
             value: queuePass
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
      //initContainers: [
      //  {
      //    name: 'wait-for-rabbitmq'
      //    image: 'busybox'
      //    command: [
      //      'sh'
      //      '-c'
      //      'until nc -zv rabbitmq 5672; do echo "waiting for rabbitmq"; sleep 2; done;'
      //    ]
      //    resources: {
      //      cpu: json('0.25')
      //      memory: '0.5Gi'
      //    }
      //  }
      //]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource makelineservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'makeline-service'
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
        external: false
        targetPort: 3001
        transport: 'http'
        allowInsecure: true // required for this service due to limitations in the original application
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
              value: queueUsername
            }
            {
              name: 'ORDER_QUEUE_PASSWORD'
              value: queuePass
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource productservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'product-service'
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
        external: false
        targetPort: 3002
        transport: 'http'
        allowInsecure: false
        clientCertificateMode: 'accept'
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
              value: 'https://${aiservice.properties.configuration.ingress.fqdn}'
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource aiservice 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'ai-service'
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
        external: false
        targetPort: 5001
        transport: 'http'
        allowInsecure: false
        clientCertificateMode: 'accept'
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
          name: 'openai-key-uri'
          keyVaultUrl: openAIKeySecretUri
          identity: managedIdentityId
        }
        {
          name: 'openai-endpoint-uri'
          keyVaultUrl: openAIEndpointSecretUri
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/azure-samples/aks-store-demo/ai-service:latest'
          name: 'product-service'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'USE_AZURE_OPENAI'
              value: 'true'
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
              value: openAIDeploymentName
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              secretRef: 'openai-endpoint-uri'
            }
            {
              name: 'OPENAI_API_KEY'
              secretRef: 'openai-key-uri'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 5001
              }
              initialDelaySeconds: 3
              periodSeconds: 3
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 5001
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource virtualcustomer 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'virtual-customer'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
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
              value: 'http://${orderservice.properties.configuration.ingress.fqdn}'
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

resource virtualworker 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'virtual-worker'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}' : {}
    }
  }
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
              value: 'http://${makelineservice.properties.configuration.ingress.fqdn}'
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
        maxReplicas: 3
      }
    }
  }  
  tags: tags
}

output makelineServiceUri string = 'https://${makelineservice.properties.configuration.ingress.fqdn}'
output orderServiceUri string =  'https://${orderservice.properties.configuration.ingress.fqdn}'
output productServiceUri string = 'https://${productservice.properties.configuration.ingress.fqdn}'
