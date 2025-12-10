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

### Deployment Workflow

The DI backend onboarding process involves coordinating with the main APIM deployment to ensure policy fragments exist before policies reference them. This workflow provides a repeatable, failure-free deployment process.

#### Prerequisites

- Main AI Hub Gateway deployment completed (`azd up`)
- Document Intelligence endpoints deployed and accessible
- Parameter files updated with actual endpoint URLs

### Step-by-Step Deployment

#### Step 1: Initial APIM Deployment

Deploy the main infrastructure which creates APIM and Document Intelligence resources:

```powershell
azd up
```

✅ **Success**: Creates APIM service, Document Intelligence API with inline policy (no fragments)

**Note**: The initial deployment uses `doc-intelligence-api-policy.xml` which contains inline backend configuration. Policy fragments don't exist yet, so the policy doesn't reference them.

#### Step 2: Get Document Intelligence Endpoint URLs

After the main deployment completes, retrieve the Document Intelligence endpoint URLs:

```powershell
# List all Document Intelligence resources in your resource group
az cognitiveservices account list --resource-group <rg-name> --query "[?kind=='FormRecognizer'].{name:name,endpoint:properties.endpoint}" -o table

# Or get specific endpoint
az cognitiveservices account show --name <di-service-name> --resource-group <rg-name> --query properties.endpoint -o tsv
```

Copy these endpoint URLs for use in the next step.

#### Step 3: Configure Backend Parameters

Create and configure your backend parameter file:

```bash
cp main.bicepparam di-backends-dev-local.bicepparam
```

Edit `di-backends-dev-local.bicepparam` with your actual values:

```bicep
using 'main.bicep'

param apim = {
  subscriptionId: '00000000-0000-0000-0000-000000000000'  // Replace with your subscription ID
  resourceGroupName: 'rg-ai-hub-citadel-dev'              // Replace with your APIM resource group
  name: 'apim-citadel-hub'                                // Replace with your APIM name
}

param apimManagedIdentity = {
  subscriptionId: '00000000-0000-0000-0000-000000000000'  // Replace with your subscription ID
  resourceGroupName: 'rg-ai-hub-citadel-dev'              // Replace with your identity resource group
  name: 'id-apim-citadel'                                 // Replace with your managed identity name
}

param diBackendConfig = [
  {
    backendId: 'di-swedencentral-primary'
    endpoint: 'https://my-di-swedencentral.cognitiveservices.azure.com/'  // Replace with actual endpoint from Step 2
    location: 'swedencentral'
    authScheme: 'managedIdentity'
    supportedOperations: [
      { name: 'prebuilt-read', capability: 'OCR and Text Extraction' }
      { name: 'prebuilt-layout', capability: 'Layout Analysis' }
      { name: 'prebuilt-invoice', capability: 'Invoice Processing' }
      { name: 'prebuilt-receipt', capability: 'Receipt Processing' }
    ]
    apiVersions: ['modern']  // or ['legacy', 'modern'] for both
    priority: 1
    weight: 100
  }
]
```

**Important**: Use the actual endpoint URLs retrieved in Step 2.

#### Step 4: Deploy DI Backend Onboarding

Deploy the backend configuration to create backends, pools, and policy fragments:

```powershell
az deployment sub create `
  --location swedencentral `
  --template-file bicep/infra/di-backend-onboarding/main.bicep `
  --parameters bicep/infra/di-backend-onboarding/di-backends-dev-local.bicepparam
```

✅ **Success**: Creates APIM backends, backend pools, and policy fragments

**What gets created:**
- APIM Backend resources (e.g., `di-primary-modern`, `di-secondary-legacy`)
- Backend pools for multi-backend operations (e.g., `prebuilt-read-modern-backend-pool`)
- Policy fragments with dynamic routing logic:
  - `set-di-backend-pools-modern`
  - `set-di-backend-pools-legacy` (if legacy API versions configured)
  - `set-di-backend-authorization`
  - `set-target-di-backend-pool`

#### Step 5: Switch to Fragment-Based Policy

Now that policy fragments exist, update the Document Intelligence API policy to use them:

```powershell
# Copy the fragment-based policy to become the active policy
Copy-Item bicep/infra/modules/apim/policies/doc-intelligence-api-policy-fragments.xml `
          bicep/infra/modules/apim/policies/doc-intelligence-api-policy.xml -Force
```

**Policy Files Structure:**
- `doc-intelligence-api-policy.xml` - **Active policy** (deployed to APIM)
- `doc-intelligence-api-policy-fragments.xml` - Fragment-based version (uses include-fragment directives)
- `doc-intelligence-api-policy-no-fragments.xml` - Inline version (preserved for reference/rollback)

#### Step 6: Deploy Updated Policy

Apply the fragment-based policy to APIM:

```powershell
azd up
```

✅ **Success**: Updates Document Intelligence API policy to use policy fragments

The policy now uses dynamic backend routing based on your configuration!

### Rollback to Inline Policy

If you need to revert to the inline policy (no fragments):

```powershell
# Restore the inline policy
Copy-Item bicep/infra/modules/apim/policies/doc-intelligence-api-policy-no-fragments.xml `
          bicep/infra/modules/apim/policies/doc-intelligence-api-policy.xml -Force

# Deploy the change
azd up
```

### Updating Backend Configuration

To add, remove, or modify backends:

1. **Edit your parameter file** (`di-backends-dev-local.bicepparam`)
2. **Redeploy DI backend onboarding** (Step 4)
3. **No policy changes needed** - Policy fragments are automatically regenerated

Policy fragments will be updated with the new backend configuration, and APIM will pick up the changes automatically (cached for 24 hours).

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

After deployment (Step 4), the following policy fragments are created in APIM:

| Fragment Name | Purpose | API Version |
|---------------|---------|-------------|
| `set-di-backend-pools-legacy` | Defines backend pools for legacy API | `/formrecognizer` |
| `set-di-backend-pools-modern` | Defines backend pools for modern API | `/documentintelligence` |
| `set-di-backend-authorization` | Sets up managed identity authentication | Both |
| `set-target-di-backend-pool` | Extracts operation from request and sets cache keys | Both |

### Policy File Structure

The repository contains three policy files for the Document Intelligence API:

| File | Purpose | When Used |
|------|---------|-----------|
| `doc-intelligence-api-policy.xml` | **Active policy** deployed to APIM | Always deployed by `azd up` |
| `doc-intelligence-api-policy-fragments.xml` | Fragment-based policy template | Copy to active policy in Step 5 |
| `doc-intelligence-api-policy-no-fragments.xml` | Inline policy template (no fragments) | Preserved for rollback/reference |

### Fragment-Based Policy Structure

After Step 5, the active policy uses this structure:

```xml
<policies>
    <inbound>
        <base />
        <!--
            Document Intelligence API Policy (Modern API: /documentintelligence)
            Purpose: Routes requests to appropriate Document Intelligence backends based on operation and availability
            
            Flow:
            1. Validate Entra ID authentication (optional, controlled by entra-validate named value)
            2. Extract and validate operation parameter (modelId/classifierId) from request
            3. Configure backend pools and routing rules (dynamically generated from DI backend onboarding)
            4. Determine target backend based on operation and availability
            5. Set up managed identity authentication and route to selected backend
            6. Collect usage metrics for monitoring and billing
        -->
        
        <!-- Step 1: Validate Entra ID authentication (if enabled) -->
        <include-fragment fragment-id="aad-auth" />
        
        <!-- Remove api-key header to prevent it from being passed to backend endpoints -->
        <set-header name="api-key" exists-action="delete" />
        
        <!-- Step 2: Extract and validate operation parameter from request -->
        <include-fragment fragment-id="set-target-di-backend-pool" />
        
        <!-- Step 3: Load backend pool configurations (if not cached) -->
        <choose>
            <when condition="@(context.Variables.ContainsKey("oaClusters") == false)">
                <include-fragment fragment-id="set-di-backend-pools-modern" />
            </when>
        </choose>
        
        <!-- Step 4: Validate routes and select available backend -->
        <include-fragment fragment-id="validate-routes" />
        
        <!-- Step 5: Configure managed identity authentication and route to selected backend -->
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

### How Policy Fragments Work

1. **`set-target-di-backend-pool`**: Extracts `modelId` or `classifierId` from request URL parameters to determine the operation (e.g., "prebuilt-invoice")

2. **`set-di-backend-pools-modern`**: Dynamically generates C# code that creates backend pool configurations:
   - Lists all available backends for each operation
   - Includes location, priority, and weight information
   - Caches configuration for 24 hours

3. **`validate-routes`**: Checks backend health and selects the best available backend based on:
   - Circuit breaker state (skips backends in failure state)
   - Priority (lower number = higher priority)
   - Weight (for load balancing across same-priority backends)

4. **`set-di-backend-authorization`**: Obtains managed identity token and sets Authorization header

5. **`backend-routing`**: Routes the request to the selected backend

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

### Deployment Fails: "Policy fragment could not be found"

**Symptom**: `azd up` fails with error:
```
ValidationError: Error in element 'include-fragment' on line 29, column 10: 
Policy fragment with id 'set-target-di-backend-pool' could not be found.
```

**Root Cause**: The active policy (`doc-intelligence-api-policy.xml`) is trying to use policy fragments that don't exist yet.

**Solution**: Follow the correct deployment order:
1. Ensure Step 1 completes successfully (uses inline policy, no fragments)
2. Complete Steps 2-4 to create the policy fragments
3. Then proceed with Step 5 to switch to fragment-based policy

If you're at this error state:
```powershell
# Revert to inline policy
Copy-Item bicep/infra/modules/apim/policies/doc-intelligence-api-policy-no-fragments.xml `
          bicep/infra/modules/apim/policies/doc-intelligence-api-policy.xml -Force

# Deploy successfully
azd up

# Then continue from Step 4
```

### Backend Not Found

**Symptom**: API returns 404 or backend not found error

**Solution**:
1. Verify backend was created:
   ```powershell
   az apim backend list --resource-group <rg> --service-name <apim> -o table
   ```
2. Check backend ID matches expected pattern: `{backendId}-{apiVersion}`
   - Example: `di-primary-modern`, `di-secondary-legacy`
3. Ensure API version specified in request matches deployed backends
4. Verify the operation is in `supportedOperations` for at least one backend

### Authentication Errors

**Symptom**: 401 Unauthorized or 403 Forbidden errors

**Solution**:
1. Verify managed identity has `Cognitive Services User` role:
   ```powershell
   az role assignment list --assignee <managed-identity-principal-id> `
     --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<di-name>
   ```
2. If missing, assign the role:
   ```powershell
   az role assignment create `
     --assignee <managed-identity-principal-id> `
     --role "Cognitive Services User" `
     --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<di-name>
   ```
3. The managed identity principal ID can be found:
   ```powershell
   az identity show --name <identity-name> --resource-group <rg> --query principalId -o tsv
   ```

### Policy Not Updated After Backend Changes

**Symptom**: Made changes to backends but policy still uses old configuration

**Solution**:
1. Policy fragments cache backend pools for 24 hours
2. Clear the cache by restarting APIM or waiting for expiry
3. Or redeploy the policy fragments (re-run Step 4)
4. Verify policy fragment was updated:
   ```powershell
   az apim policy fragment show --resource-group <rg> --service-name <apim> --policy-fragment-id set-di-backend-pools-modern
   ```

### Load Balancing Not Working

**Symptom**: All requests go to same backend

**Solution**:
1. Verify multiple backends support the same operation in your parameter file
2. Check backend pool was created:
   ```powershell
   az apim backend list --resource-group <rg> --service-name <apim> --query "[?properties.type=='Pool']" -o table
   ```
3. Ensure priority and weight values are set correctly (priority 1 = highest)
4. Check if backends are in same priority tier (load balancing only happens within same priority)
5. Clear APIM cache: Policy fragments cache backend pools for 24 hours

### Circuit Breaker Issues

**Symptom**: Backend marked as unavailable incorrectly

**Solution**:
1. Review circuit breaker settings (3 failures in 5 minutes triggers 1-minute break)
2. Adjust thresholds if needed by modifying `configureCircuitBreaker` parameter
3. Check backend health and resolve underlying issues
4. Verify network connectivity from APIM to backend endpoints
5. Check Document Intelligence service quotas and limits

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
5. **Update API policies**: Use the 6-step deployment process above
   - Keep existing inline policy for Step 1
   - Deploy DI backend onboarding (Steps 2-4)
   - Switch to fragment-based policy (Steps 5-6)
6. **Deploy to production**: Roll out during maintenance window
7. **Clean up old backends**: Remove manually created backends after verification

### Important Notes for Migration

- **No downtime required**: The inline policy continues working during Steps 1-4
- **Policy fragments coexist**: Old hardcoded backends and new policy fragments can coexist temporarily
- **Gradual rollout**: Test fragment-based routing in dev before production
- **Rollback available**: Use `doc-intelligence-api-policy-no-fragments.xml` to revert if needed

## Common Deployment Patterns

### Pattern 1: Fresh Deployment (No Existing Backends)

Use the standard 6-step process as documented above. This is the cleanest approach.

### Pattern 2: Existing APIM, Adding DI Backends

If your APIM is already deployed without Document Intelligence backends:

1. **Skip Step 1** (APIM already exists)
2. **Start from Step 2**: Get DI endpoint URLs
3. **Continue Steps 3-6**: Deploy backends and update policy

### Pattern 3: Iterative Backend Updates

After initial deployment, to add/modify backends:

1. **Edit parameter file**: Update `di-backends-dev-local.bicepparam`
2. **Redeploy Step 4**: 
   ```powershell
   az deployment sub create --location swedencentral --template-file bicep/infra/di-backend-onboarding/main.bicep --parameters bicep/infra/di-backend-onboarding/di-backends-dev-local.bicepparam
   ```
3. **No policy changes needed**: Policy fragments auto-update
4. **Wait for cache expiry**: 24 hours, or clear APIM cache manually

### Pattern 4: Multi-Environment Deployment

For dev/test/prod environments:

1. **Create environment-specific parameter files**:
   - `di-backends-dev.bicepparam`
   - `di-backends-test.bicepparam`
   - `di-backends-prod.bicepparam`
2. **Deploy to each environment**: Use appropriate parameter file
3. **Maintain separate policies**: Each environment gets its own policy fragments
4. **Promote gradually**: Dev → Test → Prod

## Support and Feedback

For issues, questions, or feedback:
- Review the [main repository documentation](../../README.md)
- Check existing issues in the repository
- Create a new issue with detailed information

## Related Documentation

- [LLM Backend Onboarding](../llm-backend-onboarding/README.md) - Similar approach for LLM backends
- [Full Deployment Guide](../../../guides/full-deployment-guide.md) - Complete AI Citadel setup
- [Document Intelligence API Documentation](https://learn.microsoft.com/azure/ai-services/document-intelligence/) - Microsoft official docs
