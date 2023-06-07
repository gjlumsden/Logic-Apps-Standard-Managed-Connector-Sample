param connectionName string
param location string = resourceGroup().location
param tenantId string
param objectId string
param logicAppName string

#disable-next-line BCP081
resource connection 'Microsoft.Web/connections@2018-07-01-preview' existing = {
  name: connectionName
} 

#disable-next-line BCP081
resource connectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: connection
  name: logicAppName
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: tenantId
        objectId: objectId
      }
    }
  }
}
