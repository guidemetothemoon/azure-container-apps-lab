param location string
param tags object
param vnetAddressSpace string
param vnetName string

var subnets = [
  {
    name: 'snet-aca-chaos-nyan-cat'
    subnetPrefix: '172.16.0.0/23'
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'vnet-${vnetName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.subnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
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

output vnetId string = vnet.id
output vnetName string = vnet.name
output acaSubnetName string = vnet.properties.subnets[0].name
output acaSubnetId string = vnet.properties.subnets[0].id
output acaSubnetIpRange string = vnet.properties.subnets[0].properties.addressPrefix
