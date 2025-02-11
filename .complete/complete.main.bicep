@description('ShortName is required for a unique storage account name. Only 5 characters.')
param shortName string = 'mystr'
param vnetName string = 'vnet-mcjava-priv'
param vnetAddressPrefixes array = [
  '192.168.1.0/24'
]
param time string = utcNow()
param subnetAzureFirewallName string = 'AzureFirewallSubnet'
param subnetAzureFirewallPrefix string = '192.168.1.0/26'
param subnetStorageName string = 'storage'
param subnetStoragePrefix string = '192.168.1.64/27'
param subnetWebName string = 'web'
param subnetWebPrefix string = '192.168.1.96/27'
param subnetAzureFirewallManagementName string = 'AzureFirewallManagementSubnet'
param subnetAzureFirewallManagementPrefix string = '192.168.1.128/26'
param pdnsName string = 'privatelink.blob.core.windows.net'
param workspaceName string = 'oiwmin001'
param location string = resourceGroup().location
param storageAccountName string = '${shortName}mcjavaservfiles'
param blobName string = 'mcjavablob'

param mngEnvName string = 'mc0101'

param cappsName string = 'capmcjava01'

module vnet 'br/public:avm/res/network/virtual-network:0.5.2' = {
  name: '${time}-privateVnet'
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      {
        name: subnetAzureFirewallName
        addressPrefix: subnetAzureFirewallPrefix
      }
      {
        name: subnetStorageName
        addressPrefix: subnetStoragePrefix
      }
      {
        name: subnetWebName
        addressPrefix: subnetWebPrefix
        delegation: 'Microsoft.App/environments'
      }
      {
        name: subnetAzureFirewallManagementName
        addressPrefix: subnetAzureFirewallManagementPrefix
      }
    ]
  }
}

module pdnssto 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: '${time}-storagedns'
  params: {
    name: pdnsName
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnet.outputs.resourceId
      }
    ]
  }
}

module pip 'br/public:avm/res/network/public-ip-address:0.7.1' = {
  name: '${time}-publicIpAddressDeployment'
  params: {
    // Required parameters
    name: 'npiawaf001'
    // Non-required parameters

    diagnosticSettings: [
      {
        workspaceResourceId: workspace.outputs.resourceId
      }
    ]
    lock: {
      kind: 'CanNotDelete'
      name: 'myCustomLockName'
    }
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    roleAssignments: []
    skuName: 'Standard'
    skuTier: 'Regional'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
  }
}

module azfw 'br/public:avm/res/network/azure-firewall:0.5.2' = {
  name: '${time}-azureFirewallDeployment'
  params: {
    // Required parameters
    name: 'azfw001'
    azureSkuTier: 'Standard'
    virtualNetworkResourceId: vnet.outputs.resourceId
    location: location
    threatIntelMode: 'Alert'
    networkRuleCollections: [
      {
        name: 'allow-outbound'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 1000
          rules: [
            {
              name: 'allow-all'
              protocols: [
                'Any'
              ]
              destinationPorts: [
                '*'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
            }
          ]
        }
      }
      {
        name: 'allow-in-minecraft'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 1001
          rules: [
            {
              name: 'allow-in-minecraft'
              protocols: [
                'Any'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '192.168.1.96/27'
              ]
              destinationPorts: [
                '25565'
              ]
            }
          ]
        }
      }
    ]
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: '${time}-storageAccountDeployment'
  params: {
    // Required parameters
    name: storageAccountName
    // Non-required parameters
    allowBlobPublicAccess: true
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          enableNfsV3AllSquash: true
          enableNfsV3RootSquash: true
          name: blobName
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyDays: 9
      deleteRetentionPolicyEnabled: true
      diagnosticSettings: [
        {
          metricCategories: [
            {
              category: 'AllMetrics'
            }
          ]
          name: 'customSetting'

          workspaceResourceId: workspace.outputs.resourceId
        }
      ]
      lastAccessTimeTrackingPolicyEnabled: true
    }
    diagnosticSettings: [
      {
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        name: 'customSetting'

        workspaceResourceId: workspace.outputs.resourceId
      }
    ]
    enableHierarchicalNamespace: true
    enableNfsV3: true
    enableSftp: true
    fileServices: {
      diagnosticSettings: [
        {
          metricCategories: [
            {
              category: 'AllMetrics'
            }
          ]
          name: 'customSetting'
          workspaceResourceId: workspace.outputs.resourceId
        }
      ]
      shares: [
        {
          accessTier: 'Hot'
          name: 'mcjavashare'
          shareQuota: 5120
        }
      ]
    }
    largeFileSharesState: 'Enabled'
    localUsers: []
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    managementPolicyRules: []
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: pdnssto.outputs.resourceId
            }
          ]
        }
        service: 'blob'
        subnetResourceId: vnet.outputs.subnetResourceIds[1]
        tags: {
          Environment: 'Non-Prod'
          'hidden-title': 'This is visible in the resource name'
          Role: 'DeploymentValidation'
        }
      }
    ]
    requireInfrastructureEncryption: true
    sasExpirationPeriod: '180.00:00:00'
    skuName: 'Standard_ZRS'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
  }
}

module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: '${time}-workspaceDeployment'
  params: {
    // Required parameters
    name: workspaceName
    // Non-required parameters
    location: location
  }
}

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.8.1' = {
  name: '${time}-managedEnvironmentDeployment'
  params: {
    // Required parameters
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    name: mngEnvName
    // Non-required parameters
    dockerBridgeCidr: '172.16.0.1/28'
    infrastructureResourceGroupName: 'mngmctest01'
    infrastructureSubnetId: vnet.outputs.subnetResourceIds[2]
    internal: true
    location: location
    storages: [
      {
        storageAccountName: storageAccount.outputs.name
        shareName: 'mcjavashare'
        accessMode: 'ReadWrite'
        kind: 'SMB'
      }
    ]
    platformReservedCidr: '172.17.17.0/24'
    platformReservedDnsIP: '172.17.17.17'
    workloadProfiles: [
      {
        maximumCount: 3
        minimumCount: 0
        name: 'CAW01'
        workloadProfileType: 'D4'
      }
    ]
  }
}

module capps 'br/public:avm/res/app/container-app:0.12.0' = {
  name: '${time}-${cappsName}'
  params: {
    name: cappsName
    containers: [
      {
        image: 'docker.io/itzg/minecraft-server'
        name: 'minecraft'
        resources: {
          cpu: json('2')
          memory: '4Gi'
        }
        volumeMounts: [
          {
            volumeName: 'mcjavashare'
            mountPath: '/data'
          }
        ]
        env: [
          { name: 'EULA', value: 'true' }
          { name: 'MEMORY', value: '4G' }
          { name: 'DIFFICULTY', value: 'normal' }
          { name: 'SERVER_NAME', value: 'Minecraft' }
          { name: 'OPS', value: 'mattffffff' }
          { name: 'VIEW_DISTANCE', value: '32' }
          { name: 'ONLINE_MODE', value: 'true' }
        ]
      }
    ]
    volumes: [
      {
        name: 'mcjavashare'
        storageAccountName: storageAccount.outputs.name
        shareName: 'mcjavashare'
      }
    ]
    ingressTargetPort: 25565
    workloadProfileName: 'CAW01'
    environmentResourceId: managedEnvironment.outputs.resourceId
  }
}
// Container Insights
