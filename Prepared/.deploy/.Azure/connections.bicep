param logicAppName string
param appNamePrefix string
@allowed([
  'd'
  'i'
  'p'
])
param env string = 'd'

@description('The location of the deployed resources. Defaults to the Resource Group location')
param location string = resourceGroup().location

var locationAbbr = {
  uksouth: 'uks'
  ukwest: 'ukw'
  //More required for other locations
}
var baseName = '${appNamePrefix}${env}${substring(uniqueString(resourceGroup().id),0,6)}${locationAbbr[location]}'
var blobConnectionName = '${baseName}blobconn'
var storageAccountName = '${baseName}actstg'
var blobConnectionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/azureblob'

resource logicApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: logicAppName
}

resource blobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

//Create role assignment for logic app to access storage account
resource logicAppStorageAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uniqueString(logicApp.id, blobDataContributorRole.id))
  scope: storageAccount
  properties: {
    roleDefinitionId: blobDataContributorRole.id
    principalId: logicApp.identity.principalId
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  parent: blobService
  name: 'blobs'
}

#disable-next-line BCP081
resource azureBlobConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: blobConnectionName
  location: location
  kind: 'V2'
  properties: {
    displayName: 'Blob Connection'
    parameterValueSet:{
      name: 'managedIdentityAuth'
      values:{}
    }
    customParameterValues:{}
    api: {
#disable-next-line use-resource-id-functions
      id: blobConnectionId
    }
  }
}

module connectionAccessPolicy 'modules/connectionAccessPolicy.bicep' = {
  name: 'connectionAccessPolicy'
  params: {
    connectionName: azureBlobConnection.name
    objectId: logicApp.identity.principalId
    tenantId: logicApp.identity.tenantId
    location: location
    logicAppName: logicApp.name
  }
}

// resource connectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
//   parent: azureBlobConnection
//   name: logicAppName
//   location: location
//   properties: {
//     principal: {
//       type: 'ActiveDirectory'
//       identity: {
//         tenantId: logicApp.identity.tenantId
//         objectId: logicApp.identity.principalId
//       }
//     }
//   }
// }

output blobConnectionRuntimeUrl string = azureBlobConnection.properties.connectionRuntimeUrl
output storageAccountName string = storageAccount.name
output blobConnectionName string = azureBlobConnection.name
