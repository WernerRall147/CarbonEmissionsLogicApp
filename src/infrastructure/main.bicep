@description('Main deployment template for Carbon Emissions Logic App solution')
@minLength(1)
@maxLength(50)
param projectName string = 'carbon-emissions'

@description('Environment name (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Array of subscription IDs to export carbon emissions data for')
param subscriptionIds array = []

@description('Schedule day of month (1-28) when Logic App should run')
@minValue(1)
@maxValue(28)
param scheduleDay int = 20

@description('Storage account name for CSV exports (must be globally unique)')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Container name for storing CSV files')
param containerName string = 'carbon-emissions-reports'

@description('Carbon API version to use')
param carbonApiVersion string = '2025-04-01'

@description('Resource token for naming consistency')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

@description('Tags to apply to all resources')
var tags = {
  project: projectName
  environment: environmentName
  'azd-env-name': environmentName
  purpose: 'carbon-emissions-export'
  'managed-by': 'bicep'
}

// Storage Account for CSV exports
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Enforce Azure AD authentication only
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        enabled: true
        days: 30
      }
      containerDeleteRetentionPolicy: {
        enabled: true
        days: 30
      }
    }
  }
}

// Blob container for CSV files
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: storageAccount::blobServices
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'carbon-emissions-csv-exports'
    }
  }
}

// Logic App for carbon emissions export workflow
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'carbon-export-logic-app'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    parameters: {
      subscriptionIds: {
        value: subscriptionIds
      }
      storageAccountName: {
        value: storageAccount.name
      }
      containerName: {
        value: containerName
      }
      carbonApiVersion: {
        value: carbonApiVersion
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        subscriptionIds: {
          type: 'Array'
          defaultValue: []
        }
        storageAccountName: {
          type: 'String'
        }
        containerName: {
          type: 'String'
        }
        carbonApiVersion: {
          type: 'String'
          defaultValue: '2025-04-01'
        }
      }
      triggers: {
        monthlyRecurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Month'
            interval: 1
            schedule: {
              monthDays: [scheduleDay]
              hours: [0]
              minutes: [0]
            }
            timeZone: 'UTC'
          }
        }
      }
      actions: {
        // Variables initialization
        initializePreviousMonth: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'previousMonth'
                type: 'String'
                value: '@formatDateTime(addToTime(utcNow(), -2, \'Month\'), \'yyyy-MM-01\')'
              }
            ]
          }
          runAfter: {}
        }
        initializeMonthYearLabel: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'monthYearLabel'
                type: 'String'
                value: '@formatDateTime(addToTime(utcNow(), -2, \'Month\'), \'MMMyyyy\')'
              }
            ]
          }
          runAfter: {
            initializePreviousMonth: ['Succeeded']
          }
        }
        initializePast12MonthsStart: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'past12MonthsStart'
                type: 'String'
                value: '@formatDateTime(addToTime(utcNow(), -14, \'Month\'), \'yyyy-MM-01\')'
              }
            ]
          }
          runAfter: {
            initializeMonthYearLabel: ['Succeeded']
          }
        }

        // Data availability check
        checkDataAvailability: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.Carbon/queryCarbonEmissionDataAvailableDateRange'
            queries: {
              'api-version': '@parameters(\'carbonApiVersion\')'
            }
            headers: {
              'Content-Type': 'application/json'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com/'
            }
          }
          runAfter: {
            initializePast12MonthsStart: ['Succeeded']
          }
        }

        // Query subscription emissions
        querySubscriptionEmissions: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.Carbon/carbonEmissionReports'
            queries: {
              'api-version': '@parameters(\'carbonApiVersion\')'
            }
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              reportType: 'ItemDetailReport'
              subscriptionList: '@parameters(\'subscriptionIds\')'
              carbonScopeList: ['Scope1', 'Scope2', 'Scope3']
              dateRange: {
                start: '@variables(\'previousMonth\')'
                end: '@variables(\'previousMonth\')'
              }
              categoryType: 'Subscription'
              orderBy: 'totalCarbonEmission'
              sortDirection: 'Desc'
              pageSize: 1000
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com/'
            }
            retryPolicy: {
              type: 'Fixed'
              count: 3
              interval: 'PT1M'
            }
          }
          runAfter: {
            checkDataAvailability: ['Succeeded']
          }
        }

        // Transform and create subscription CSV
        transformSubscriptionData: {
          type: 'Select'
          inputs: {
            from: '@body(\'querySubscriptionEmissions\').value'
            select: {
              Subscription_Name: '@item().itemName'
              Subscription_Id: '@item().subscriptionId'
              Latest_Month_Emissions_kgCO2E: '@item().totalCarbonEmission'
              Previous_Month_Emissions_kgCO2E: '@item().totalCarbonEmissionLastMonth'
            }
          }
          runAfter: {
            querySubscriptionEmissions: ['Succeeded']
          }
        }

        createSubscriptionCSV: {
          type: 'Table'
          inputs: {
            from: '@body(\'transformSubscriptionData\')'
            format: 'CSV'
          }
          runAfter: {
            transformSubscriptionData: ['Succeeded']
          }
        }

        // Query monthly trends
        queryMonthlyTrends: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.Carbon/carbonEmissionReports'
            queries: {
              'api-version': '@parameters(\'carbonApiVersion\')'
            }
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              reportType: 'MonthlySummaryReport'
              subscriptionList: '@parameters(\'subscriptionIds\')'
              carbonScopeList: ['Scope1', 'Scope2', 'Scope3']
              dateRange: {
                start: '@variables(\'past12MonthsStart\')'
                end: '@variables(\'previousMonth\')'
              }
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com/'
            }
            retryPolicy: {
              type: 'Fixed'
              count: 3
              interval: 'PT1M'
            }
          }
          runAfter: {
            checkDataAvailability: ['Succeeded']
          }
        }

        // Transform and create trends CSV
        transformTrendsData: {
          type: 'Select'
          inputs: {
            from: '@body(\'queryMonthlyTrends\').value'
            select: {
              Month: '@formatDateTime(item().date, \'MMM yyyy\')'
              TotalEmissions: '@item().latestMonthEmissions'
              Scope1: '0'
              Scope2: '0'
              Scope3: '@item().latestMonthEmissions'
              CarbonIntensity: '@item().carbonIntensity'
            }
          }
          runAfter: {
            queryMonthlyTrends: ['Succeeded']
          }
        }

        createTrendsCSV: {
          type: 'Table'
          inputs: {
            from: '@body(\'transformTrendsData\')'
            format: 'CSV'
          }
          runAfter: {
            transformTrendsData: ['Succeeded']
          }
        }

        // Upload CSVs to blob storage
        uploadSubscriptionCSV: {
          type: 'Http'
          inputs: {
            method: 'PUT'
            uri: 'https://@{parameters(\'storageAccountName\')}.blob.core.windows.net/@{parameters(\'containerName\')}/EmissionDetails-Subscription-@{variables(\'monthYearLabel\')}.csv'
            headers: {
              'Content-Type': 'text/csv'
              'x-ms-blob-type': 'BlockBlob'
            }
            body: '@body(\'createSubscriptionCSV\')'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://storage.azure.com/'
            }
            retryPolicy: {
              type: 'Fixed'
              count: 3
              interval: 'PT30S'
            }
          }
          runAfter: {
            createSubscriptionCSV: ['Succeeded']
          }
        }

        uploadTrendsCSV: {
          type: 'Http'
          inputs: {
            method: 'PUT'
            uri: 'https://@{parameters(\'storageAccountName\')}.blob.core.windows.net/@{parameters(\'containerName\')}/EmissionTrends-@{variables(\'monthYearLabel\')}.csv'
            headers: {
              'Content-Type': 'text/csv'
              'x-ms-blob-type': 'BlockBlob'
            }
            body: '@body(\'createTrendsCSV\')'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://storage.azure.com/'
            }
            retryPolicy: {
              type: 'Fixed'
              count: 3
              interval: 'PT30S'
            }
          }
          runAfter: {
            createTrendsCSV: ['Succeeded']
          }
        }
      }
    }
  }
}

// RBAC: Grant Logic App Storage Blob Data Contributor role on storage account
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicApp.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    ) // Storage Blob Data Contributor
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'  }
}

// Note: Cross-subscription RBAC assignments need to be configured manually
// Grant the Logic App's managed identity "Carbon Optimization Reader" role 
// on each target subscription using Azure Portal or CLI

// Outputs
@description('Logic App resource ID')
output logicAppId string = logicApp.id

@description('Logic App name')
output logicAppName string = logicApp.name

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage container name')
output containerName string = container.name

@description('Logic App managed identity principal ID')
output logicAppPrincipalId string = logicApp.identity.principalId

@description('Storage account blob endpoint')
output storageAccountBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
