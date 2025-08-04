// Virtual Machine Module with Security Best Practices
@description('Location for all resources.')
param location string

@description('Id of the subnet.')
param subnetId string

@description('Name of the virtual machine.')
param vmName string

@description('Size of the virtual machine.')
param vmSize string

@description('Username for the Virtual Machine.')
param username string

@description('Password for the Virtual Machine.')
@minLength(12)
@secure()
param password string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Enable accelerated networking for the network interface.')
param enableAcceleratedNetworking bool = false

@description('Enable boot diagnostics.')
param enableBootDiagnostics bool = true

@description('Storage account URI for boot diagnostics. If not provided, managed storage will be used.')
param bootDiagnosticsStorageUri string = ''

// Create Public IP Address with Standard SKU for better security
resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard' // Use Standard SKU for better security and features
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static' // Static allocation for Standard SKU
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')
      domainNameLabelScope: 'TenantReuse' // Scope for domain name label
    }
    // DDoS protection inherits from virtual network
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

// Create Network Interface with security configurations
resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: enableAcceleratedNetworking
    enableIPForwarding: false // Disable IP forwarding for security
    disableTcpStateTracking: false // Keep TCP state tracking enabled
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: pip.id
            properties: {
              deleteOption: 'Delete' // Delete public IP when VM is deleted
            }
          }
          subnet: {
            id: subnetId
          }
          primary: true
        }
      }
    ]
  }
}

// Create Virtual Machine with security best practices
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: username
      adminPassword: password
      allowExtensionOperations: true
      requireGuestProvisionSignal: false
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform' // Enable automatic patching
          assessmentMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired' // Reboot if required for patches
            bypassPlatformSafetyChecksOnUserSchedule: false
          }
          enableHotpatching: false // Can be enabled for supported VM sizes
        }
        timeZone: 'UTC' // Set explicit timezone
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-22h2-pro' // Updated to newer Windows 11 version
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete' // Delete OS disk when VM is deleted
        managedDisk: {
          storageAccountType: 'Premium_LRS' // Use Premium SSD for better performance
        }
        diskSizeGB: 127 // Explicit disk size
        writeAcceleratorEnabled: false
      }
      dataDisks: [] // No data disks by default
      diskControllerType: 'SCSI' // Explicit disk controller type
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete' // Delete NIC when VM is deleted
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: enableBootDiagnostics
        storageUri: enableBootDiagnostics && !empty(bootDiagnosticsStorageUri) ? bootDiagnosticsStorageUri : null
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch' // Enable Trusted Launch for enhanced security
      uefiSettings: {
        secureBootEnabled: true // Enable Secure Boot
        vTpmEnabled: true // Enable virtual TPM
      }
      encryptionAtHost: false // Can be enabled if supported by VM size
    }
    priority: 'Regular' // Regular priority (not Spot)
    evictionPolicy: null // Not applicable for regular VMs
    billingProfile: null // Not applicable for regular VMs
    extensionsTimeBudget: 'PT1H30M' // 90 minutes for extensions
    // Enable scheduled events for better maintenance handling
    scheduledEventsProfile: {
      terminateNotificationProfile: {
        enable: true
        notBeforeTimeout: 'PT5M' // 5 minutes notification before termination
      }
      osImageNotificationProfile: {
        enable: true
        notBeforeTimeout: 'PT15M' // 15 minutes notification before OS image updates
      }
    }
  }
}

// Outputs for integration and reference
@description('The fully qualified domain name (FQDN) of the virtual machine.')
output vmHostname string = pip.properties.dnsSettings.fqdn

@description('The public IP address of the virtual machine.')
output vmPublicIP string = pip.properties.ipAddress

@description('The private IP address of the virtual machine.')
output vmPrivateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('The resource ID of the virtual machine.')
output vmResourceId string = vm.id

@description('The resource ID of the network interface.')
output nicResourceId string = nic.id

@description('The resource ID of the public IP address.')
output publicIPResourceId string = pip.id

@description('The name of the virtual machine.')
output vmName string = vm.name

@description('The location of the virtual machine.')
output vmLocation string = vm.location

@description('The security configuration of the virtual machine.')
output securityConfiguration object = {
  trustedLaunchEnabled: vm.properties.securityProfile.securityType == 'TrustedLaunch'
  secureBootEnabled: vm.properties.securityProfile.uefiSettings.secureBootEnabled
  vTpmEnabled: vm.properties.securityProfile.uefiSettings.vTpmEnabled
  automaticPatchingEnabled: vm.properties.osProfile.windowsConfiguration.patchSettings.patchMode == 'AutomaticByPlatform'
}
