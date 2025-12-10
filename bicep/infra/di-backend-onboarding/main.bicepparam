using 'main.bicep'

// ============================================================================
// DI Backend Onboarding - Parameter File
// ============================================================================
// This parameter file configures Document Intelligence backends for an existing
// APIM instance. It creates backend resources, backend pools, and policy 
// fragments for dynamic operation-based routing.
//
// REQUIRED PARAMETERS: apim, apimManagedIdentity, diBackendConfig
// OPTIONAL PARAMETERS: configureCircuitBreaker
// ============================================================================

// ============================================================================
// REQUIRED: API Management (APIM) Configuration
// ============================================================================
// Specifies the target APIM instance where DI backends will be onboarded.
// This APIM instance should already exist and have the necessary networking
// and security configurations in place.
//
// Properties:
// - subscriptionId: Azure subscription ID where APIM is deployed
// - resourceGroupName: Resource group containing the APIM instance
// - name: Name of the APIM service instance
// ============================================================================
param apim = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your APIM resource group
  name: 'apim-citadel-governance-hub'                    // Replace with your APIM name
}

// ============================================================================
// REQUIRED: APIM Managed Identity Configuration
// ============================================================================
// Specifies the user-assigned managed identity used by APIM for backend
// authentication. This identity must have the appropriate RBAC role:
// - Cognitive Services User (for Document Intelligence backends)
//
// Properties:
// - subscriptionId: Azure subscription ID where the identity is deployed
// - resourceGroupName: Resource group containing the managed identity
// - name: Name of the user-assigned managed identity
// ============================================================================
param apimManagedIdentity = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your identity resource group
  name: 'id-apim-citadel'                                // Replace with your managed identity name
}

// ============================================================================
// REQUIRED: Document Intelligence Backend Configuration Array
// ============================================================================
// Defines all Document Intelligence backends that APIM will route requests to.
// Each backend object should have:
//
// Required Properties:
// - backendId: Unique identifier (used in APIM backend resource name)
// - endpoint: Base URL of the Document Intelligence service
// - location: Azure region where the DI instance is deployed
// - authScheme: 'managedIdentity' | 'apiKey' | 'token'
// - supportedOperations: Array of operation objects (see below)
// - apiVersions: Array of API versions to support: ['legacy', 'modern'] or subset
//
// Optional Properties (for load balancing):
// - priority: 1-5, default 1 (lower = higher priority for load balancing)
// - weight: 1-1000, default 100 (higher = more traffic share)
//
// Operation Object Properties (in supportedOperations array):
// - name: Operation name (required) - e.g., 'prebuilt-read', 'prebuilt-invoice'
// - capability: Capability description (optional, defaults to operation name)
//
// API Versions:
// - 'legacy': Supports /formrecognizer path (API v2.1, v3.0, v3.1)
// - 'modern': Supports /documentintelligence path (API v4.0+)
//
// Example configurations for different scenarios are shown below.
// ============================================================================
param diBackendConfig = [
  // ----------------------------------
  // Document Intelligence Backend - Primary (East US)
  // ----------------------------------
  // This backend connects to a Document Intelligence instance in East US
  // Supports both legacy and modern API paths
  {
    backendId: 'di-eastus-primary'
    endpoint: 'https://YOUR-DI-RESOURCE-EUS.cognitiveservices.azure.com/' // Replace with your DI endpoint
    location: 'eastus'
    authScheme: 'managedIdentity'
    // Supported operations for this backend
    supportedOperations: [
      { name: 'prebuilt-read', capability: 'OCR and Text Extraction' }
      { name: 'prebuilt-layout', capability: 'Layout Analysis' }
      { name: 'prebuilt-invoice', capability: 'Invoice Processing' }
      { name: 'prebuilt-receipt', capability: 'Receipt Processing' }
      { name: 'prebuilt-idDocument', capability: 'ID Document Processing' }
      { name: 'prebuilt-healthInsuranceCard.us', capability: 'Health Insurance Card Processing' }
      { name: 'prebuilt-businessCard', capability: 'Business Card Processing' }
      { name: 'prebuilt-document', capability: 'General Document Processing' }
    ]
    // Support both legacy and modern API versions
    apiVersions: ['legacy', 'modern']
    priority: 1
    weight: 100
  }
  
  // ----------------------------------
  // Document Intelligence Backend - Secondary (West US)
  // ----------------------------------
  // For load balancing and failover, add backends in different regions
  // Operations shared with primary backend will be load balanced
  {
    backendId: 'di-westus-secondary'
    endpoint: 'https://YOUR-DI-RESOURCE-WUS.cognitiveservices.azure.com/' // Replace with your secondary DI endpoint
    location: 'westus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read', capability: 'OCR and Text Extraction' }
      { name: 'prebuilt-layout', capability: 'Layout Analysis' }
      { name: 'prebuilt-invoice', capability: 'Invoice Processing' }
      { name: 'prebuilt-receipt', capability: 'Receipt Processing' }
    ]
    // Support only modern API for this backend
    apiVersions: ['modern']
    priority: 2
    weight: 50
  }

  // ----------------------------------
  // Document Intelligence Backend - Specialized (Central US)
  // ----------------------------------
  // Example of a backend with specialized operations
  // Uncomment to add
  // {
  //   backendId: 'di-centralus-specialized'
  //   endpoint: 'https://YOUR-DI-RESOURCE-CUS.cognitiveservices.azure.com/'
  //   location: 'centralus'
  //   authScheme: 'managedIdentity'
  //   supportedOperations: [
  //     { name: 'prebuilt-healthInsuranceCard.us', capability: 'Health Insurance Card Processing' }
  //     { name: 'prebuilt-tax.us.w2', capability: 'W2 Tax Form Processing' }
  //     { name: 'prebuilt-tax.us.1040', capability: '1040 Tax Form Processing' }
  //   ]
  //   apiVersions: ['modern']
  //   priority: 1
  //   weight: 100
  // }
]

// ============================================================================
// OPTIONAL: Circuit Breaker Configuration
// ============================================================================
// Enable circuit breaker for backend resilience. When enabled, APIM will
// temporarily stop routing to backends that are experiencing failures.
//
// Recommended: true for production environments
// ============================================================================
param configureCircuitBreaker = true
