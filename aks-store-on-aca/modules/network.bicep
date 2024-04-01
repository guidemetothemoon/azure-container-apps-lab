param environment string
param location string
param locationPrefix string
param subnets array
param tags object
param vnetIpRange string

var vnetName = 'vnet-${locationPrefix}-${environment}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIpRange
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]      
        }    
      }
    ]
  }
  tags: tags
}

// Network Security Group includes mandatory rules for Azure Container Apps.
// Ref. https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${vnetName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAny1194UDPAzureCloudOutbound'
        properties: {
          protocol: 'UDP'
          sourcePortRange: '*'
          destinationPortRange: '1194'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud.${location}'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAny9000TCPAzureCloudOutbound'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '9000'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud.${location}'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAny443AzureMonitorOutbound'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAnyContainerAppsControlPlaneTCPOutbound'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
          destinationPortRanges: [
            '443'
            '5671'
            '5672'
          ]
        }
      }
      {
        name: 'AllowAny123NTPOutbound'
        properties: {
          protocol: 'UDP'
          sourcePortRange: '*'
          destinationPortRange: '123'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
    ]
  }
  tags: tags
}

output acaSubnetId string = vnet.properties.subnets[0].id
output acaSubnetIpRange string = vnet.properties.subnets[0].properties.addressPrefix
output nsgName string = nsg.name
output vnetId string = vnet.id
