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

@description('Enable Application Insights and Log Analytics for monitoring.')
param enableMonitoring bool = true


// Creation of the Web App
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    // Enable zone redundancy for better availability
    zoneRedundant: false // Set to true for production workloads
  }
}

resource webApplication 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
    Environment: 'Demo'
    Purpose: 'Cross-Tenant-Private-Endpoint-Demo'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false // Improves performance for stateless apps
    httpsOnly: true // Force HTTPS-only traffic
    publicNetworkAccess: 'Disabled' // Disable public access since we're using private endpoints
    siteConfig: {
      minTlsVersion: '1.2' // Enforce minimum TLS version
      scmMinTlsVersion: '1.2' // Enforce minimum TLS version for SCM
      ftpsState: 'Disabled' // Disable FTP
      alwaysOn: false //  Set to true for production workloads to keep the app warm
      http20Enabled: true // Enable HTTP/2
      use32BitWorkerProcess: false // Use 64-bit for better performance
      //healthCheckPath: '/health' // Add health check endpoint (you'll need to implement this)
      ipSecurityRestrictionsDefaultAction: 'Deny' // Deny by default
      scmIpSecurityRestrictionsDefaultAction: 'Deny' // Deny SCM by default
    }
  }
}

// Monitoring module (optional)
module monitoring 'module/monitoring.bicep' = if (enableMonitoring) {
  name: 'monitoring'
  params: {
    location: location
    uniqueSuffix: uniqueString(resourceGroup().id)
    tags: {
      Environment: 'Demo'
      Purpose: 'Cross-Tenant-Private-Endpoint-Demo'
    }
    retentionInDays: 30
    applicationType: 'web'
  }
}

// Configure Application Insights settings if monitoring is enabled
resource webAppSettings 'Microsoft.Web/sites/config@2024-04-01' = if (enableMonitoring) {
  name: 'appsettings'
  parent: webApplication
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: monitoring!.outputs.applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: monitoring!.outputs.applicationInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
  }
}

@description('The URL of the web application.')
output webApplicationUrl string = 'https://${webApplication.properties.defaultHostName}'

@description('The ID of the web application. This is used to create the private endpoint in the Consumer Tenant.')
output webApplicationId string = webApplication.id

@description('The hostname of the virtual machine for testing.')
output vmHostname string = virtualMachine.outputs.vmHostname

@description('The private IP address of the private endpoint.')
output privateEndpointIP string = privateEndpoint.properties.networkInterfaces[0].properties.ipConfigurations[0].properties.privateIPAddress

@description('The Application Insights instrumentation key (if monitoring is enabled).')
output applicationInsightsInstrumentationKey string = enableMonitoring ? monitoring!.outputs.applicationInsightsInstrumentationKey : ''

@description('The Application Insights connection string (if monitoring is enabled).')
output applicationInsightsConnectionString string = enableMonitoring ? monitoring!.outputs.applicationInsightsConnectionString : ''

@description('The resource ID of the private DNS zone.')
output privateDnsZoneId string = privateDnsZone.id

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
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: location
  tags: {
    Environment: 'Demo'
    Purpose: 'Cross-Tenant-Private-Endpoint-Demo'
  }
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
    customNetworkInterfaceName: '${privateEndpointName}-nic'
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

resource privateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
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
