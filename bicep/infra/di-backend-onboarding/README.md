# 🚀 Document Intelligence Backend Onboarding for AI Citadel Governance Hub

## Overview

Automate the onboarding of Document Intelligence backends to your APIM-based AI Gateway with a streamlined, infrastructure-as-code approach using **Bicep parameter files** (`.bicepparam`).

This package enables dynamic Document Intelligence backend routing without manually modifying APIM policies:

- 📦 **Automatic Backend Creation**: Create APIM backends from configuration
- ⚖️ **Load Balancing**: Distribute requests across multiple backends for the same operation
- 🔄 **Automatic Failover**: Route to healthy backends when others are unavailable
- 🔌 **Dual API Support**: Support both legacy (`/formrecognizer`) and modern (`/documentintelligence`) paths
- 📝 **Declarative Configuration**: Simple `.bicepparam` files for version control

## What Gets Created

| Resource | Description |
|----------|-------------|
| **APIM Backends** | Individual backend resources for each Document Intelligence endpoint (per API version) |
| **Backend Pools** | Load-balanced pools for operations with multiple backends |
| **Policy Fragments** | Dynamic routing logic for operation-based routing |

## Prerequisites

- Existing deployment of AI Citadel Governance Hub with:
  - User-assigned managed identity configured
  - Document Intelligence APIs (modern and/or legacy)
- Document Intelligence instances deployed and accessible:
  - Document Intelligence resources with supported operations
  - APIM can reach the target backends from network perspective
- Verify APIM's user assigned managed identity has required role:
   - `Cognitive Services User` for Document Intelligence instances

## Quick Start

### 1. Copy the Parameter Template

```bash
cp main.bicepparam di-backends-dev-local.bicepparam
```

### 2. Configure Your Backends

Edit `di-backends-dev-local.bicepparam`:

```bicep
using 'main.bicep'

param apim = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your APIM resource group
  name: 'apim-citadel-governance-hub'                    // Replace with your APIM name
}

param apimManagedIdentity = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your identity resource group
  name: 'id-apim-citadel'                                // Replace with your managed identity name
}

param diBackendConfig = [
  {
    backendId: 'di-eastus-primary'
    endpoint: 'https://my-di-eastus.cognitiveservices.azure.com/'
    location: 'eastus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read', capability: 'OCR and Text Extraction' }
      { name: 'prebuilt-layout', capability: 'Layout Analysis' }
      { name: 'prebuilt-invoice', capability: 'Invoice Processing' }
      { name: 'prebuilt-receipt', capability: 'Receipt Processing' }
    ]
    apiVersions: ['legacy', 'modern']
    priority: 1
    weight: 100
  }
]
```

### 3. Deploy

```bash
az deployment sub create \
  --name di-backend-onboarding \
  --location eastus \
  --template-file main.bicep \
  --parameters di-backends-dev-local.bicepparam
```

## Configuration Reference

### Backend Configuration Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `backendId` | string | Yes | Unique identifier for the backend (usually the name of the backend resource) |
| `endpoint` | string | Yes | Base URL of the Document Intelligence service |
| `location` | string | Yes | Azure region where the DI instance is deployed |
| `authScheme` | string | Yes | `managedIdentity`, `apiKey`, or `token` |
| `supportedOperations` | array | Yes | Array of operation objects (see Operation Object Properties below) |
| `apiVersions` | array | Yes | API versions to support: `['legacy']`, `['modern']`, or `['legacy', 'modern']` |
| `priority` | number | No | 1-5, default 1 (lower = higher priority) |
| `weight` | number | No | 1-1000, default 100 (load balancing weight) |

### Operation Object Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Operation name (e.g., 'prebuilt-read', 'prebuilt-invoice') |
| `capability` | string | No | Human-readable capability description |

### Common Document Intelligence Operations

| Operation Name | Description |
|----------------|-------------|
| `prebuilt-read` | OCR and text extraction |
| `prebuilt-layout` | Layout analysis with tables and structure |
| `prebuilt-invoice` | Invoice processing |
| `prebuilt-receipt` | Receipt processing |
| `prebuilt-idDocument` | ID document extraction (driver's license, passport) |
| `prebuilt-businessCard` | Business card extraction |
| `prebuilt-healthInsuranceCard.us` | US health insurance card processing |
| `prebuilt-tax.us.w2` | W2 tax form processing |
| `prebuilt-document` | General document analysis |

## Usage Scenarios

### Scenario 1: Single Document Intelligence Backend

Deploy a single Document Intelligence instance supporting multiple operations:

```bicep
param diBackendConfig = [
  {
    backendId: 'di-primary'
    endpoint: 'https://my-di.cognitiveservices.azure.com/'
    location: 'eastus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read' }
      { name: 'prebuilt-layout' }
      { name: 'prebuilt-invoice' }
    ]
    apiVersions: ['modern']
    priority: 1
    weight: 100
  }
]
```

### Scenario 2: Multi-Region with Load Balancing

Deploy multiple backends for high availability and load balancing:

```bicep
param diBackendConfig = [
  {
    backendId: 'di-eastus'
    endpoint: 'https://my-di-eastus.cognitiveservices.azure.com/'
    location: 'eastus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read' }
      { name: 'prebuilt-invoice' }
    ]
    apiVersions: ['legacy', 'modern']
    priority: 1
    weight: 100
  }
  {
    backendId: 'di-westus'
    endpoint: 'https://my-di-westus.cognitiveservices.azure.com/'
    location: 'westus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read' }
      { name: 'prebuilt-invoice' }
    ]
    apiVersions: ['modern']
    priority: 2
    weight: 50
  }
]
```

In this scenario:
- Requests for `prebuilt-read` and `prebuilt-invoice` will be load balanced across both backends
- Primary backend (East US) gets 67% of traffic (weight 100 vs 50)
- Modern API calls can use both backends, legacy API only uses East US
- Automatic failover if one backend becomes unavailable

### Scenario 3: Specialized Backend with Unique Operations

Deploy a specialized backend for specific document types:

```bicep
param diBackendConfig = [
  {
    backendId: 'di-general'
    endpoint: 'https://my-di-general.cognitiveservices.azure.com/'
    location: 'eastus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read' }
      { name: 'prebuilt-layout' }
    ]
    apiVersions: ['modern']
    priority: 1
    weight: 100
  }
  {
    backendId: 'di-healthcare'
    endpoint: 'https://my-di-healthcare.cognitiveservices.azure.com/'
    location: 'centralus'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-healthInsuranceCard.us' }
    ]
    apiVersions: ['modern']
    priority: 1
    weight: 100
  }
]
```

## API Version Support

### Legacy API (`/formrecognizer`)

- Supports Document Intelligence API versions 2.1, 3.0, and 3.1
- Endpoint pattern: `{endpoint}/formrecognizer`
- Example URL: `https://my-di.cognitiveservices.azure.com/formrecognizer/documentModels/prebuilt-invoice:analyze?api-version=2023-07-31`

### Modern API (`/documentintelligence`)

- Supports Document Intelligence API version 4.0 and later
- Endpoint pattern: `{endpoint}/documentintelligence`
- Example URL: `https://my-di.cognitiveservices.azure.com/documentintelligence/documentModels/prebuilt-invoice:analyze?api-version=2024-11-30`

To support both APIs, specify `apiVersions: ['legacy', 'modern']` in your backend configuration.

## How It Works

### 1. Backend Creation

For each backend configuration, the deployment creates APIM backend resources:
- If `apiVersions` includes `'legacy'`, creates a backend named `{backendId}-legacy` with endpoint `{endpoint}/formrecognizer`
- If `apiVersions` includes `'modern'`, creates a backend named `{backendId}-modern` with endpoint `{endpoint}/documentintelligence`

### 2. Backend Pool Creation

Operations supported by multiple backends are grouped into backend pools:
- Pool name format: `{operation}-{apiVersion}-backend-pool`
- Example: `prebuilt-invoice-modern-backend-pool` for modern API invoice processing

### 3. Dynamic Routing

Policy fragments are created with routing logic:
- Extracts operation name from request URL (`modelId` or `classifierId` parameter)
- Selects appropriate backend pool based on operation and API version
- Applies priority and weight-based load balancing
- Handles failover to alternate backends

### 4. Authentication

All backends use managed identity authentication:
- APIM's user-assigned managed identity authenticates to Document Intelligence
- Access token obtained with scope `https://cognitiveservices.azure.com`
- Token cached and reused across requests

## Policy Fragment Integration

After deployment, the following policy fragments are available:

| Fragment Name | Purpose | Usage |
|---------------|---------|-------|
| `set-di-backend-pools-legacy` | Defines backend pools for legacy API | Include in legacy API policy |
| `set-di-backend-pools-modern` | Defines backend pools for modern API | Include in modern API policy |
| `set-di-backend-authorization` | Sets up managed identity auth | Include in both API policies |
| `set-target-di-backend-pool` | Selects target backend | Include in both API policies |

### Example: Updating Existing API Policy

To use the newly created backend pools, update your Document Intelligence API policy:

```xml
<policies>
    <inbound>
        <base />
        <!-- Include fragment for target backend selection -->
        <include-fragment fragment-id="set-target-di-backend-pool" />
        
        <!-- Load backend pools if not cached -->
        <choose>
            <when condition="@(context.Variables.ContainsKey("oaClusters") == false)">
                <!-- Include generated backend pools for modern API -->
                <include-fragment fragment-id="set-di-backend-pools-modern" />
            </when>
        </choose>
        
        <!-- Validate routes -->
        <include-fragment fragment-id="validate-routes" />
        
        <!-- Set up authentication -->
        <include-fragment fragment-id="set-di-backend-authorization" />
    </inbound>
    <backend>
        <include-fragment fragment-id="backend-routing" />
    </backend>
    <outbound>
        <base />
        <!-- Usage tracking and response handling -->
    </outbound>
</policies>
```

## Deployment Outputs

After successful deployment, the following outputs are available:

| Output | Description |
|--------|-------------|
| `apimServiceName` | Name of the APIM service |
| `apimGatewayUrl` | Gateway URL for API requests |
| `backendIds` | Array of created backend IDs |
| `poolNames` | Array of created backend pool names |
| `operationToPoolMap` | Mapping of operations to their backend pools |
| `operationToBackendMap` | Mapping of operations to direct backends |
| `supportedOperations` | All supported operations across backends |
| `policyFragments` | Names of created policy fragments |

## Troubleshooting

### Backend Not Found

**Symptom**: API returns 404 or backend not found error

**Solution**:
1. Verify backend was created: `az apim backend list --resource-group <rg> --service-name <apim>`
2. Check backend ID matches expected pattern: `{backendId}-{apiVersion}`
3. Ensure API version specified in request matches deployed backends

### Authentication Errors

**Symptom**: 401 Unauthorized or 403 Forbidden errors

**Solution**:
1. Verify managed identity has `Cognitive Services User` role:
   ```bash
   az role assignment list --assignee <managed-identity-principal-id> --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<di-name>
   ```
2. If missing, assign the role:
   ```bash
   az role assignment create \
     --assignee <managed-identity-principal-id> \
     --role "Cognitive Services User" \
     --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<di-name>
   ```

### Load Balancing Not Working

**Symptom**: All requests go to same backend

**Solution**:
1. Verify multiple backends support the same operation
2. Check backend pool was created: Look for pool name in outputs
3. Ensure priority and weight values are set correctly
4. Clear APIM cache: Policy fragments cache backend pools for 24 hours

### Circuit Breaker Issues

**Symptom**: Backend marked as unavailable incorrectly

**Solution**:
1. Review circuit breaker settings (3 failures in 5 minutes triggers 1-minute break)
2. Adjust thresholds if needed by modifying `configureCircuitBreaker` parameter
3. Check backend health and resolve underlying issues

## Best Practices

### 1. Multi-Region Deployment

Deploy backends in multiple Azure regions for:
- **High availability**: Automatic failover during regional outages
- **Low latency**: Route requests to nearest region
- **Load distribution**: Spread traffic across regions

### 2. Priority and Weight Configuration

- **Priority**: Use for primary/secondary patterns (primary=1, secondary=2)
- **Weight**: Use for proportional traffic distribution (primary=100, secondary=50 = 67%/33% split)

### 3. API Version Strategy

- **Migrate gradually**: Support both legacy and modern initially
- **Deprecate legacy**: Remove legacy support after full migration
- **Modern API benefits**: Better performance, new features

### 4. Operation Granularity

- **Group similar operations**: Don't create too many specialized backends
- **Separate by SLA**: Different backends for different SLA requirements
- **Monitor utilization**: Adjust based on actual usage patterns

### 5. Circuit Breaker Configuration

- **Production**: Always enable (`configureCircuitBreaker: true`)
- **Development**: Can disable for easier troubleshooting
- **Tune thresholds**: Adjust based on your resilience requirements

## Migration from Manual Backend Configuration

If you have manually configured Document Intelligence backends:

1. **Document existing configuration**: Note backend IDs, endpoints, and supported operations
2. **Create parameter file**: Convert manual configuration to `.bicepparam` format
3. **Test in non-production**: Deploy to development environment first
4. **Verify routing**: Ensure all operations route correctly
5. **Update API policies**: Replace hardcoded backend references with policy fragments
6. **Deploy to production**: Roll out during maintenance window
7. **Clean up old backends**: Remove manually created backends after verification

## Support and Feedback

For issues, questions, or feedback:
- Review the [main repository documentation](../../README.md)
- Check existing issues in the repository
- Create a new issue with detailed information

## Related Documentation

- [LLM Backend Onboarding](../llm-backend-onboarding/README.md) - Similar approach for LLM backends
- [Full Deployment Guide](../../../guides/full-deployment-guide.md) - Complete AI Citadel setup
- [Document Intelligence API Documentation](https://learn.microsoft.com/azure/ai-services/document-intelligence/) - Microsoft official docs
