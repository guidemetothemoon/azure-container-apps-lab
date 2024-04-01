param privateDnsZones array
param tags object

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones : {
  name: zone
  location: 'global'
  properties: {}
  tags: tags
}]
