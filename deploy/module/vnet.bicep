@description('Location for all resources.')
param location string = resourceGroup().location

// Virtual Network and subnet
@description('Name of the virtual network to create.')
param vnetName string 

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string  

@description('Address prefix for the subnet.')
param subnetPrefix string 

@description('Name of the subnet to create.')
var subnetName = 'mySubnet'

@description('Name of the network security group to create - opens 3386 for RDP into the VM.')
var networkSecurityGroupName = 'myNSG'

// Creation of the virtual network and subnet and NSG
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: securityGroup.id
          }
        }
      }
    ]
  }
}

resource securityGroup 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
