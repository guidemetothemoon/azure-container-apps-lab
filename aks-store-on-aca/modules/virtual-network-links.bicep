param dnsZoneName string
param tags object
param vnetId string

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dnsZoneName
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${dnsZone.name}-link'
  parent: dnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  tags: tags
}
