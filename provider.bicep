@description('Location for all resources.')
param location string = resourceGroup().location

// Web App Service
@description('Name of the app service plan to create.')
param appServicePlanName string = 'myAppPlan-${uniqueString(resourceGroup().id)}'

@description('Name of the webapp to create.')
param webAppName string = 'myWebApp-${uniqueString(resourceGroup().id)}'

// Virtual Network and subnet
@description('Name of the virtual network to create.')
param vnetName string = 'myVirtualNetwork'

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string  = '10.0.0.0/16'

@description('Address prefix for the subnet.')
param subnetPrefix string = '10.0.0.0/24'

// Private Endpoint and Private DNS
@description('Name of the private endpoint to create.')
param privateEndpointName string = 'myPrivateEndpoint'

@description('Name of the private DNS zone group to create.')
param privateDnsGroupName string = '${privateEndpointName}/mydnsgroupname'

@description('Name of the private DNS zone config to create.')
param privateDnsZoneConfig string = 'privatendpointconfig'

@description('Name of the private DNS zone to create.')
var privateDnsZoneName = 'privatelink.azurewebsites.net'

// Virtual Machine
@description('Username for the Virtual Machine.')
param username string

@description('Password for the Virtual Machine.')
@minLength(12)
@secure()
param password string

@description('Name of the virtual machine.')
param vmName string = 'vm-pe-test'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'


// Creation of the Web App
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'S1'
    capacity: 1
  }
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }
  properties: {
    serverFarmId: appServicePlan.id
  }
}

@description('The URL of the web application.')
output webApplicationUrl string = webApplication.properties.defaultHostName

@description('The ID of the web application. This is used to create the private endpoint in the Consumer Tenant.')
output webApplicationId string = webApplication.id

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

// Creation private endpoint to the Web App
// the privateLinkServiceConnections will create an auto-approve link
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet.outputs.subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: webApplication.id
          groupIds: [
            'sites'
          ]
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

resource privateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
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
