targetScope = 'subscription'

/**
 * @module DI Backend Onboarding
 * @description Deploys Document Intelligence backends, backend pools, and policy fragments to an existing APIM instance
 * 
 * This deployment enables dynamic Document Intelligence backend routing in Azure API Management (APIM), allowing:
 * - Route requests to multiple Document Intelligence instances
 * - Load balance across multiple backends for the same operation type
 * - Automatic failover when backends are unavailable
 * - Support for both legacy (/formrecognizer) and modern (/documentintelligence) API paths
 * 
 * Usage:
 *   az deployment sub create \
 *     --location <location> \
 *     --template-file main.bicep \
 *     --parameters main.bicepparam
 */

// ============================================================================
// PARAMETERS
// ============================================================================

@description('APIM resource coordinates for the existing API Management instance')
param apim object

@description('User-assigned managed identity resource coordinates for APIM authentication')
param apimManagedIdentity object

@metadata({
  description: '''
  Each backend object should have:
  - backendId: Unique identifier (used in APIM backend resource name)
  - endpoint: Base URL of the Document Intelligence service (e.g., https://my-di-eastus.cognitiveservices.azure.com/)
  - location: Azure region where the DI instance is deployed
  - authScheme: 'managedIdentity' | 'apiKey' | 'token'
  - supportedOperations: Array of operation objects, each with:
    - name: Operation name (required, e.g., 'prebuilt-read', 'prebuilt-invoice')
    - capability: (Optional) Capability description, default to operation name
  - apiVersions: Array of API versions to support: ['legacy', 'modern'] or subset
  - priority: (Optional) 1-5, default 1 (lower = higher priority)
  - weight: (Optional) 1-1000, default 100 (higher = more traffic)
  '''
  example: [
    {
      backendId: 'di-eastus-primary'
      endpoint: 'https://my-di-eastus.cognitiveservices.azure.com/'
      location: 'eastus'
      authScheme: 'managedIdentity'
      supportedOperations: [
        { name: 'prebuilt-read', capability: 'OCR' }
        { name: 'prebuilt-layout', capability: 'Layout Analysis' }
        { name: 'prebuilt-invoice', capability: 'Invoice Processing' }
      ]
      apiVersions: ['legacy', 'modern']
      priority: 1
      weight: 100
    }
  ]
})
param diBackendConfig array

@description('Whether to configure circuit breaker for backends (recommended for production)')
param configureCircuitBreaker bool = true

// ============================================================================
// EXISTING RESOURCES
// ============================================================================

resource apimRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription(apim.subscriptionId)
  name: apim.resourceGroupName
}

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  scope: apimRg
  name: apim.name
}

resource identityRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription(apimManagedIdentity.subscriptionId)
  name: apimManagedIdentity.resourceGroupName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: identityRg
  name: apimManagedIdentity.name
}

// ============================================================================
// MODULES
// ============================================================================

/**
 * Step 1: Create Document Intelligence Backends
 * Creates individual APIM backend resources for each DI endpoint (legacy and/or modern)
 */
module diBackends 'modules/di-backends.bicep' = {
  name: 'di-backends-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    managedIdentityClientId: managedIdentity.properties.clientId
    diBackendConfig: diBackendConfig
    configureCircuitBreaker: configureCircuitBreaker
  }
}

/**
 * Step 2: Create Backend Pools
 * Groups backends by supported operations for load balancing and failover
 */
module diBackendPools 'modules/di-backend-pools.bicep' = {
  name: 'di-backend-pools-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    backendDetails: diBackends.outputs.backendDetails
  }
}

/**
 * Step 3: Generate Policy Fragments
 * Creates dynamic policy fragments with backend pool configurations
 */
module diPolicyFragments 'modules/di-policy-fragments.bicep' = {
  name: 'di-policy-fragments-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    policyFragmentConfig: diBackendPools.outputs.policyFragmentConfig
    managedIdentityClientId: managedIdentity.properties.clientId
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the APIM service')
output apimServiceName string = apim.name

@description('Gateway URL for the APIM service')
output apimGatewayUrl string = apimService.properties.gatewayUrl

@description('Array of created backend IDs')
output backendIds array = diBackends.outputs.backendIds

@description('Array of created backend pool names')
output poolNames array = diBackendPools.outputs.poolNames

@description('Mapping of operations to their backend pools')
output operationToPoolMap object = diBackendPools.outputs.operationToPoolMap

@description('Mapping of operations to direct backends (single-backend operations)')
output operationToBackendMap object = diBackendPools.outputs.operationToBackendMap

@description('All supported operations across all backends')
output supportedOperations array = union([], reduce(diBackendConfig, [], (acc, config) => union(acc, map(config.supportedOperations, op => op.name))))

@description('Policy fragment names')
output policyFragments object = {
  setBackendPools: diPolicyFragments.outputs.setBackendPoolsFragmentName
  setBackendAuthorization: diPolicyFragments.outputs.setBackendAuthorizationFragmentName
  setTargetBackendPool: diPolicyFragments.outputs.setTargetBackendPoolFragmentName
}
