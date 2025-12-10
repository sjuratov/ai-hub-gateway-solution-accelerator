/**
 * @module di-backend-pools
 * @description Creates APIM backend pools that group backends by supported operations
 * 
 * This module analyzes the Document Intelligence backend configuration and creates backend pools.
 * Each pool groups backends that support the same operation, enabling:
 * - Load balancing across multiple backends for the same operation
 * - Automatic failover if one backend becomes unavailable
 * - Priority-based and weighted routing strategies
 * 
 * Pools are created separately for legacy and modern API versions.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('Array of backend details from di-backends module output')
param backendDetails array

// ------------------
//    VARIABLES
// ------------------

// Extract operation names from supportedOperations for each backend
var normalizedBackendDetails = [for backend in backendDetails: {
  backendId: backend.backendId
  originalBackendId: backend.originalBackendId
  apiVersion: backend.apiVersion
  location: backend.location
  resourceId: backend.resourceId
  priority: backend.priority
  weight: backend.weight
  // Extract operation names
  operationNames: map(backend.supportedOperations, op => op.name)
}]

// Group backends by supported operations and API version to create backend pools
// Create a key: 'operation-name-apiVersion' to separate legacy from modern
var operationToBackendsMap = reduce(normalizedBackendDetails, {}, (acc, backend) => union(acc, reduce(backend.operationNames, {}, (opAcc, operation) => union(opAcc, {
  '${operation}-${backend.apiVersion}': union(
    acc[?'${operation}-${backend.apiVersion}'] ?? [],
    [
      {
        backendId: backend.backendId
        originalBackendId: backend.originalBackendId
        apiVersion: backend.apiVersion
        location: backend.location
        resourceId: backend.resourceId
        priority: backend.priority
        weight: backend.weight
      }
    ]
  )
}))))

// Create pool configurations only for operations supported by multiple backends
var poolConfigs = map(
  filter(items(operationToBackendsMap), (item) => length(item.value) > 1),
  (item) => {
    // Parse the key to extract operation name and API version
    parts: split(item.key, '-')
    // Reconstruct operation name (everything except last part which is apiVersion)
    operationName: join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')
    apiVersion: last(split(item.key, '-'))
    poolName: '${join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')}-${last(split(item.key, '-'))}-backend-pool'
    backends: item.value
  }
)

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Create backend pools for operations with multiple backend options
resource backendPools 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for config in poolConfigs: {
  name: config.poolName
  parent: apimService
  properties: {
    description: 'Backend pool for operation: ${config.operationName} (${config.apiVersion} API)'
    type: 'Pool'
    #disable-next-line BCP035
    pool: {
      services: [for backend in config.backends: {
        id: '/backends/${backend.backendId}'
        priority: backend.priority
        weight: backend.weight
      }]
    }
  }
}]

// ------------------
//    OUTPUTS
// ------------------

@description('Array of created backend pool names')
output poolNames array = [for (config, i) in poolConfigs: backendPools[i].name]

@description('Mapping of operations (with API version) to their backend pool names')
output operationToPoolMap object = reduce(poolConfigs, {}, (acc, config) => union(acc, {
  '${config.operationName}-${config.apiVersion}': config.poolName
}))

@description('Mapping of operations (with API version) to backend IDs (for operations with single backend)')
output operationToBackendMap object = reduce(
  filter(items(operationToBackendsMap), (item) => length(item.value) == 1),
  {},
  (acc, item) => {
    // Parse the key to extract operation name and API version
    operationName: join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')
    apiVersion: last(split(item.key, '-'))
    return: union(acc, {
      '${join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')}-${last(split(item.key, '-'))}': item.value[0].backendId
    })
  }
)

@description('Complete pool configurations including backend details')
output poolDetails array = [for (config, i) in poolConfigs: {
  operationName: config.operationName
  apiVersion: config.apiVersion
  poolName: config.poolName
  poolType: 'pool'
  backends: config.backends
}]

@description('Configuration for policy fragment generation')
output policyFragmentConfig object = {
  backendPools: map(poolConfigs, config => {
    poolName: config.poolName
    apiVersion: config.apiVersion
    supportedOperations: [config.operationName]
    backends: config.backends // Include backend details for location info
  })
  directBackends: map(
    filter(items(operationToBackendsMap), (item) => length(item.value) == 1),
    (item) => {
      operationName: join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')
      apiVersion: last(split(item.key, '-'))
      poolName: item.value[0].backendId
      location: item.value[0].location
      supportedOperations: [join(take(split(item.key, '-'), length(split(item.key, '-')) - 1), '-')]
    }
  )
}
