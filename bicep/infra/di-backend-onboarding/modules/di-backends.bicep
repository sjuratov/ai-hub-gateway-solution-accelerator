/**
 * @module di-backends
 * @description Creates APIM backends for Document Intelligence services
 * 
 * This module dynamically creates backend resources based on the provided configuration array.
 * Each backend represents a Document Intelligence endpoint that can serve one or more operations.
 * Backends are created for each API version specified (legacy and/or modern).
 * 
 * Supported API versions:
 * - legacy: /formrecognizer path (API v2.1, v3.0, v3.1)
 * - modern: /documentintelligence path (API v4.0+)
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('User-assigned managed identity client ID for authentication')
param managedIdentityClientId string

@description('Configuration array for Document Intelligence backends')
param diBackendConfig array

@description('Whether to configure circuit breaker for backends')
param configureCircuitBreaker bool = true

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Create individual backends for each DI endpoint - Legacy API
resource diBackendsLegacy 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for config in filter(diBackendConfig, c => contains(c.apiVersions, 'legacy')): {
  name: '${config.backendId}-legacy'
  parent: apimService
  properties: {
    description: 'Document Intelligence Backend: ${config.backendId} (legacy) - ${config.location} - Supports operations: ${join(map(config.supportedOperations, op => op.name), ', ')}'
    url: endsWith(config.endpoint, '/') ? '${substring(config.endpoint, 0, length(config.endpoint) - 1)}/formrecognizer' : '${config.endpoint}/formrecognizer'
    protocol: 'http'
    
    // Circuit breaker configuration for resilience
    circuitBreaker: configureCircuitBreaker ? {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
              {
                min: 500
                max: 503
              }
            ]
          }
          name: '${config.backendId}-legacy-breaker-rule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    } : null
    
    // Authentication configuration based on auth scheme
    credentials: config.authScheme == 'managedIdentity' ? {
      header: {
        'x-ms-client-id': [
          managedIdentityClientId
        ]
      }
    } : {}
    
    // TLS configuration for secure communication
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

// Create individual backends for each DI endpoint - Modern API
resource diBackendsModern 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for config in filter(diBackendConfig, c => contains(c.apiVersions, 'modern')): {
  name: '${config.backendId}-modern'
  parent: apimService
  properties: {
    description: 'Document Intelligence Backend: ${config.backendId} (modern) - ${config.location} - Supports operations: ${join(map(config.supportedOperations, op => op.name), ', ')}'
    url: endsWith(config.endpoint, '/') ? '${substring(config.endpoint, 0, length(config.endpoint) - 1)}/documentintelligence' : '${config.endpoint}/documentintelligence'
    protocol: 'http'
    
    // Circuit breaker configuration for resilience
    circuitBreaker: configureCircuitBreaker ? {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
              {
                min: 500
                max: 503
              }
            ]
          }
          name: '${config.backendId}-modern-breaker-rule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    } : null
    
    // Authentication configuration based on auth scheme
    credentials: config.authScheme == 'managedIdentity' ? {
      header: {
        'x-ms-client-id': [
          managedIdentityClientId
        ]
      }
    } : {}
    
    // TLS configuration for secure communication
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

// ------------------
//    OUTPUTS
// ------------------

// Separate outputs for each API version
var legacyBackendIds = [for (config, i) in filter(diBackendConfig, c => contains(c.apiVersions, 'legacy')): diBackendsLegacy[i].name]
var modernBackendIds = [for (config, i) in filter(diBackendConfig, c => contains(c.apiVersions, 'modern')): diBackendsModern[i].name]

var legacyBackendDetails = [for (config, i) in filter(diBackendConfig, c => contains(c.apiVersions, 'legacy')): {
  backendId: '${config.backendId}-legacy'
  originalBackendId: config.backendId
  apiVersion: 'legacy'
  location: config.location
  resourceId: diBackendsLegacy[i].id
  supportedOperations: config.supportedOperations
  priority: config.?priority ?? 1
  weight: config.?weight ?? 100
}]

var modernBackendDetails = [for (config, i) in filter(diBackendConfig, c => contains(c.apiVersions, 'modern')): {
  backendId: '${config.backendId}-modern'
  originalBackendId: config.backendId
  apiVersion: 'modern'
  location: config.location
  resourceId: diBackendsModern[i].id
  supportedOperations: config.supportedOperations
  priority: config.?priority ?? 1
  weight: config.?weight ?? 100
}]

@description('Array of created backend IDs')
output backendIds array = concat(legacyBackendIds, modernBackendIds)

@description('Array of backend configurations with resource IDs')
output backendDetails array = concat(legacyBackendDetails, modernBackendDetails)
