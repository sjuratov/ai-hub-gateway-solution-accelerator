/*
 * @module di-policy-fragments
 * @description Generates APIM policy fragments with backend pool configurations
 * 
 * This module creates policy fragments that contain the dynamically generated
 * backend pool configurations based on the Document Intelligence backend setup.
 * These fragments are used by the Document Intelligence API policies to route
 * requests appropriately.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('Policy fragment configuration from backend pools module')
param policyFragmentConfig object

@description('User-assigned managed identity client ID for authentication')
param managedIdentityClientId string

// ------------------
//    VARIABLES
// ------------------

// Separate pools and direct backends by API version
var legacyBackendPools = filter(policyFragmentConfig.backendPools, pool => pool.apiVersion == 'legacy')
var modernBackendPools = filter(policyFragmentConfig.backendPools, pool => pool.apiVersion == 'modern')
var legacyDirectBackends = filter(policyFragmentConfig.directBackends, backend => backend.apiVersion == 'legacy')
var modernDirectBackends = filter(policyFragmentConfig.directBackends, backend => backend.apiVersion == 'modern')

// Generate C# code for legacy - backend pools (multiple backends per operation)
var legacyPoolsArray = [for (pool, index) in legacyBackendPools: replace(replace(replace('// Operation: OPERATIONS (Backend Pool)\nvar route_INDEX = new JObject()\n{\n    { "name", "POOLNAME" },\n    { "location", "Pool" },\n    { "backend-id", "POOLNAME" },\n    { "priority", 1},\n    { "isThrottling", false },\n    { "retryAfter", DateTime.MinValue }\n};\nroutes.Add(route_INDEX);\n\nclusters.Add(new JObject()\n{\n    { "deploymentName", "OPERATIONS" },\n    { "routes", new JArray(route_INDEX) }\n});', 'POOLNAME', pool.poolName), 'INDEX', string(index)), 'OPERATIONS', join(pool.supportedOperations, '", "'))]
var legacyPoolsCode = join(legacyPoolsArray, '\n')

// Generate C# code for legacy - direct backends (single backend per operation)
var legacyDirectArray = [for (backend, index) in legacyDirectBackends: replace(replace(replace(replace('// Operation: OPERATIONS (Direct Backend)\nvar route_INDEXD = new JObject()\n{\n    { "name", "BACKENDID" },\n    { "location", "LOCATION" },\n    { "backend-id", "BACKENDID" },\n    { "priority", 1},\n    { "isThrottling", false },\n    { "retryAfter", DateTime.MinValue }\n};\nroutes.Add(route_INDEXD);\n\nclusters.Add(new JObject()\n{\n    { "deploymentName", "OPERATIONS" },\n    { "routes", new JArray(route_INDEXD) }\n});', 'BACKENDID', backend.poolName), 'LOCATION', backend.location), 'INDEXD', '${index}d'), 'OPERATIONS', join(backend.supportedOperations, '", "'))]
var legacyDirectCode = join(legacyDirectArray, '\n')

var legacyBackendPoolsCode = '${legacyPoolsCode}\n${legacyDirectCode}'

// Generate C# code for modern - backend pools (multiple backends per operation)
var modernPoolsArray = [for (pool, index) in modernBackendPools: replace(replace(replace('// Operation: OPERATIONS (Backend Pool)\nvar route_INDEX = new JObject()\n{\n    { "name", "POOLNAME" },\n    { "location", "Pool" },\n    { "backend-id", "POOLNAME" },\n    { "priority", 1},\n    { "isThrottling", false },\n    { "retryAfter", DateTime.MinValue }\n};\nroutes.Add(route_INDEX);\n\nclusters.Add(new JObject()\n{\n    { "deploymentName", "OPERATIONS" },\n    { "routes", new JArray(route_INDEX) }\n});', 'POOLNAME', pool.poolName), 'INDEX', string(index)), 'OPERATIONS', join(pool.supportedOperations, '", "'))]
var modernPoolsCode = join(modernPoolsArray, '\n')

// Generate C# code for modern - direct backends (single backend per operation)
var modernDirectArray = [for (backend, index) in modernDirectBackends: replace(replace(replace(replace('// Operation: OPERATIONS (Direct Backend)\nvar route_INDEXD = new JObject()\n{\n    { "name", "BACKENDID" },\n    { "location", "LOCATION" },\n    { "backend-id", "BACKENDID" },\n    { "priority", 1},\n    { "isThrottling", false },\n    { "retryAfter", DateTime.MinValue }\n};\nroutes.Add(route_INDEXD);\n\nclusters.Add(new JObject()\n{\n    { "deploymentName", "OPERATIONS" },\n    { "routes", new JArray(route_INDEXD) }\n});', 'BACKENDID', backend.poolName), 'LOCATION', backend.location), 'INDEXD', '${index}d'), 'OPERATIONS', join(backend.supportedOperations, '", "'))]
var modernDirectCode = join(modernDirectArray, '\n')

var modernBackendPoolsCode = '${modernPoolsCode}\n${modernDirectCode}'

// Load policy fragment templates
var setBackendPoolsLegacyFragmentTemplate = loadTextContent('./policies/frag-set-di-backend-pools-legacy.xml')
var setBackendPoolsModernFragmentTemplate = loadTextContent('./policies/frag-set-di-backend-pools-modern.xml')
var setBackendAuthorizationFragmentXml = loadTextContent('./policies/frag-set-di-backend-authorization.xml')
var setTargetBackendPoolFragmentXml = loadTextContent('./policies/frag-set-target-di-backend-pool.xml')

// Inject generated backend pools code into templates
var updatedSetBackendPoolsLegacyFragmentXml = replace(setBackendPoolsLegacyFragmentTemplate, '//{backendPoolsCode}', legacyBackendPoolsCode)
var updatedSetBackendPoolsModernFragmentXml = replace(setBackendPoolsModernFragmentTemplate, '//{backendPoolsCode}', modernBackendPoolsCode)

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Named value for managed identity client ID (reuse if exists)
resource uamiClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'uami-client-id'
  parent: apimService
  properties: {
    displayName: 'uami-client-id'
    value: managedIdentityClientId
    secret: false
  }
}

// Policy Fragment: Set Backend Pools - Legacy API
resource setBackendPoolsLegacyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-di-backend-pools-legacy'
  parent: apimService
  properties: {
    description: 'Dynamically generated backend pool configurations for Document Intelligence routing (Legacy API: /formrecognizer)'
    format: 'rawxml'
    value: updatedSetBackendPoolsLegacyFragmentXml
  }
}

// Policy Fragment: Set Backend Pools - Modern API
resource setBackendPoolsModernFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-di-backend-pools-modern'
  parent: apimService
  properties: {
    description: 'Dynamically generated backend pool configurations for Document Intelligence routing (Modern API: /documentintelligence)'
    format: 'rawxml'
    value: updatedSetBackendPoolsModernFragmentXml
  }
}

// Policy Fragment: Set Backend Authorization
resource setBackendAuthorizationFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-di-backend-authorization'
  parent: apimService
  properties: {
    description: 'Authentication configuration for Document Intelligence backends'
    format: 'rawxml'
    value: setBackendAuthorizationFragmentXml
  }
}

// Policy Fragment: Set Target Backend Pool
resource setTargetBackendPoolFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-target-di-backend-pool'
  parent: apimService
  properties: {
    description: 'Target backend selection logic for Document Intelligence operations'
    format: 'rawxml'
    value: setTargetBackendPoolFragmentXml
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('Name of the set backend pools fragment for legacy API')
output setBackendPoolsLegacyFragmentName string = setBackendPoolsLegacyFragment.name

@description('Name of the set backend pools fragment for modern API')
output setBackendPoolsModernFragmentName string = setBackendPoolsModernFragment.name

@description('Name of the set backend pools fragment (defaults to modern)')
output setBackendPoolsFragmentName string = setBackendPoolsModernFragment.name

@description('Name of the set backend authorization fragment')
output setBackendAuthorizationFragmentName string = setBackendAuthorizationFragment.name

@description('Name of the set target backend pool fragment')
output setTargetBackendPoolFragmentName string = setTargetBackendPoolFragment.name
