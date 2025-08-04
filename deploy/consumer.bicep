@description('Location for all resources.')
param location string = resourceGroup().location

@description('Resource Id of the Web Application to connect to.')
param providerTenantWebApplicationId string

// vnet and subnet
@description('Name of the virtual network to create.')
param vnetName string = 'myVirtualNetwork'

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the subnet.')
param subnetPrefix string = '10.0.0.0/24'

// private Endpoint and private DNS
@description('Name of the private endpoint to create.')
param privateEndpointName string = 'myPrivateEndpoint'

@description('Request message for the private endpoint connection.')
param privateEndpointConnectionRequestMessage string = 'Please approve my connection'

@description('Name of the private DNS zone group to create.')
param privateDnsGroupName string = '${privateEndpointName}/mydnsgroupname'

@description('Name of the private DNS zone config to create.')
param privateDnsZoneConfig string = 'privatendpointconfig'

@description('Name of the private DNS zone to create.')
var privateDnsZoneName = 'privatelink.azurewebsites.net'

// Virtual Machine
@description('Name of the virtual machine.')
param vmName string = 'vm-pe-test'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'

@description('Username for the Virtual Machine.')
param username string

@description('Password for the Virtual Machine.')
@minLength(12)
@secure()
param password string

// Creation of the virtual network and subnet and NSG
module vnet 'module/vnet.bicep'= {
  name: 'vnet'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetPrefix: subnetPrefix
  }
}

// Creation private endpoint to Tenant Web App
// the manualPrivateLinkServiceConnections will create a pending connection request
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet.outputs.subnetId
    }
    manualPrivateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: providerTenantWebApplicationId
          groupIds: [
            'sites'
          ]
          requestMessage: privateEndpointConnectionRequestMessage
        }
      }
    ]
  }
}

// Create Private DNS and Private DNS Virtual Network Link
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.outputs.vnetId
    }
  }
}

// Add Private Endpoint in Private DNS Zone
resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: privateDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneConfig
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}

// Create the VM
module virtualMachine 'module/vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    subnetId: vnet.outputs.subnetId
    username: username 
    password: password
    vmName: vmName
    vmSize: vmSize
  }
}

@description('The hostname of the virtual machine for testing.')
output vmHostname string = virtualMachine.outputs.vmHostname
