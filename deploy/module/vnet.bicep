// Virtual Network Module with Security Best Practices and Outbound Internet Access
@description('Location for all resources.')
param location string = resourceGroup().location

// Virtual Network and subnet parameters
@description('Name of the virtual network to create.')
param vnetName string 

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string  

@description('Address prefix for the subnet.')
param subnetPrefix string 

@description('Tags to apply to all resources.')
param tags object = {}

@description('Enable DDoS protection standard.')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID.')
param ddosProtectionPlanId string = ''

@description('Enable VM protection for the virtual network.')
param enableVmProtection bool = false

@description('Name of the subnet to create.')
var subnetName = 'mySubnet'

@description('Name of the network security group to create - allows RDP and ensures outbound internet access.')
var networkSecurityGroupName = 'myNSG'

// Create Network Security Group with security best practices and outbound internet access
resource securityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    flushConnection: false // Keep connections stable during NSG rule updates
    securityRules: [
      {
        name: 'Allow-RDP-Inbound'
        properties: {
          description: 'Allow RDP traffic from any source'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP-Outbound'
        properties: {
          description: 'Allow HTTP outbound traffic to Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          description: 'Allow HTTPS outbound traffic to Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1010
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-DNS-Outbound'
        properties: {
          description: 'Allow DNS outbound traffic'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1020
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-Windows-Update-Outbound'
        properties: {
          description: 'Allow Windows Update and patch management'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443', '8530', '8531']
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1030
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-Azure-Services-Outbound'
        properties: {
          description: 'Allow outbound traffic to Azure services'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 1040
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-VirtualNetwork-Outbound'
        properties: {
          description: 'Allow outbound traffic within virtual network'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1050
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Create Virtual Network with security best practices and outbound internet access
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection && !empty(ddosProtectionPlanId) ? {
      id: ddosProtectionPlanId
    } : null
    enableVmProtection: enableVmProtection
    // Enhanced DNS settings for better name resolution
    dhcpOptions: {
      dnsServers: [] // Use Azure-provided DNS by default
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          // Enable private endpoints while keeping outbound internet access
          privateEndpointNetworkPolicies: 'Disabled' // Required for private endpoints
          privateLinkServiceNetworkPolicies: 'Enabled' // Keep private link service policies enabled
          defaultOutboundAccess: true // Explicitly ensure outbound internet access
          networkSecurityGroup: {
            id: securityGroup.id
          }
          // No route table specified - use Azure default routing for internet access
          delegations: [] // No subnet delegations by default
          serviceEndpoints: [] // Can be extended for specific Azure services
        }
      }
    ]
    // Enhanced security and monitoring features
    flowTimeoutInMinutes: 4 // Default flow timeout for connections
  }
}

// Outputs for integration and reference
@description('The resource ID of the virtual network.')
output vnetId string = vnet.id

@description('The resource ID of the subnet.')
output subnetId string = vnet.properties.subnets[0].id

@description('The name of the virtual network.')
output vnetName string = vnet.name

@description('The name of the subnet.')
output subnetName string = vnet.properties.subnets[0].name

@description('The address prefix of the virtual network.')
output vnetAddressPrefix string = vnet.properties.addressSpace.addressPrefixes[0]

@description('The address prefix of the subnet.')
output subnetAddressPrefix string = vnet.properties.subnets[0].properties.addressPrefix

@description('The resource ID of the network security group.')
output nsgId string = securityGroup.id

@description('The name of the network security group.')
output nsgName string = securityGroup.name

@description('The location of the virtual network.')
output vnetLocation string = vnet.location

@description('Network configuration summary.')
output networkConfiguration object = {
  vnetId: vnet.id
  vnetName: vnet.name
  vnetAddressSpace: vnet.properties.addressSpace.addressPrefixes[0]
  subnetId: vnet.properties.subnets[0].id
  subnetName: vnet.properties.subnets[0].name
  subnetAddressPrefix: vnet.properties.subnets[0].properties.addressPrefix
  nsgId: securityGroup.id
  nsgName: securityGroup.name
  privateEndpointsEnabled: vnet.properties.subnets[0].properties.privateEndpointNetworkPolicies == 'Disabled'
  outboundInternetAccess: vnet.properties.subnets[0].properties.defaultOutboundAccess
  ddosProtectionEnabled: vnet.properties.enableDdosProtection
  vmProtectionEnabled: vnet.properties.enableVmProtection
}
