import { replaceMultipleStrings } from '../functions.bicep'

param environmentId string
param location string
param makelineServiceUri string
param managedIdentityId string
param orderServiceUri string
param productServiceUri string
param tags object

var storeFrontNginxConfReplacements = { 
  '{ORDER_SERVICE_URI}': orderServiceUri
  '{PRODUCT_SERVICE_URI}': productServiceUri
}

var storeAdminNginxConfReplacements = { 
  '{MAKELINE_SERVICE_URI}': makelineServiceUri
  '{ORDER_SERVICE_URI}': orderServiceUri
  '{PRODUCT_SERVICE_URI}': productServiceUri
}

var storeFrontNginxConf = replaceMultipleStrings(loadTextContent('storeFrontNginx.conf'), storeFrontNginxConfReplacements)
var storeAdminNginxConf = replaceMultipleStrings(loadTextContent('storeAdminNginx.conf'), storeAdminNginxConfReplacements)

resource storefront 'Microsoft.App/containerApps@2023-05-02-preview' = {
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
        targetPort: 8080
        transport: 'http'
        clientCertificateMode: 'accept'
      }
      secrets: [
        {
          name: 'nginx-conf'
          value: storeFrontNginxConf
        }
      ]
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
          command: [
            '/bin/sh'
            '-c'
            'echo Ready to serve! && nginx -g \'daemon off;\''
          ]
          volumeMounts: [
            {
              mountPath: '/etc/nginx/conf.d/'
              volumeName: 'nginx-conf'
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
      volumes: [
        {
          name: 'nginx-conf'
          storageType: 'Secret'
          secrets: [
            {
              secretRef: 'nginx-conf'
              path: 'default.conf'
            }
            {
              secretRef: 'nginx-conf'
              path: 'nginx.conf.template'
            }
          ]
        }
      ]
    }
  }
}

resource storeadmin 'Microsoft.App/containerApps@2023-05-02-preview' = {
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
        external: true        
        targetPort: 8081
        transport: 'http'
        clientCertificateMode: 'accept'
      }
      secrets: [
        {
          name: 'nginx-conf'
          value: storeAdminNginxConf
        }
      ]
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
          command: [
            '/bin/sh'
            '-c'
            'echo Ready to serve! && nginx -g \'daemon off;\''
          ]
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
          volumeMounts: [
            {
              mountPath: '/etc/nginx/conf.d/'
              volumeName: 'nginx-conf'
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
      volumes: [
        {
          name: 'nginx-conf'
          storageType: 'Secret'
          secrets: [
            {
              secretRef: 'nginx-conf'
              path: 'default.conf'
            }
            {
              secretRef: 'nginx-conf'
              path: 'nginx.conf.template'
            }
          ]
        }
      ]
    }
  }
  tags: tags
}

output storeFrontUri string = 'https://${storefront.properties.configuration.ingress.fqdn}'
output storeAdminUri string = 'https://${storeadmin.properties.configuration.ingress.fqdn}'
