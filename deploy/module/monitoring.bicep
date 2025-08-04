// Monitoring Module - Log Analytics Workspace and Application Insights
@description('Location for all resources.')
param location string

@description('Unique suffix for resource naming.')
param uniqueSuffix string

@description('Tags to apply to resources.')
param tags object = {}

@description('Log Analytics retention period in days.')
param retentionInDays int = 30

@description('Application Insights application type.')
param applicationType string = 'web'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${uniqueSuffix}'
  location: location
  kind: applicationType
  tags: tags
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Outputs
@description('The resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The workspace ID (customer ID) of the Log Analytics workspace.')
output logAnalyticsWorkspaceWorkspaceId string = logAnalyticsWorkspace.properties.customerId

@description('The resource ID of Application Insights.')
output applicationInsightsId string = applicationInsights.id

@description('The instrumentation key for Application Insights.')
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The connection string for Application Insights.')
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString

@description('The Application ID for Application Insights.')
output applicationInsightsAppId string = applicationInsights.properties.AppId
