using '../../../main.bicep'

// ============================================================================
// Sales Assistant - Key Vault only - Generated from Notebook
// ============================================================================

param apim = {
  subscriptionId: 'ad44bcb2-464c-463f-86b8-a89d43903cbf'
  resourceGroupName: 'rg-citadel-hub-dev-1'
  name: 'apim-bc2yajbbxycfw'
}

param keyVault = {
  subscriptionId: 'ad44bcb2-464c-463f-86b8-a89d43903cbf'
  resourceGroupName: 'rg-citadel-hub-dev-1'
  name: 'kv-bc2yajbbxycsj'
}

param useTargetAzureKeyVault = true

param useCase = {
  businessUnit: 'Sales'
  useCaseName: 'Assistant'
  environment: 'DEV'
}

param apiNameMapping = {
  LLM: ['universal-llm-api', 'azure-openai-api']
}

param services = [
  {
    code: 'LLM'
    endpointSecretName: 'SALES-LLM-ENDPOINT'
    apiKeySecretName: 'SALES-LLM-KEY'
    policyXml: loadTextContent('ai-product-policy.xml')
  }
]

param productTerms = 'Access Contract created from testing notebook - Sales Assistant - Key Vault only'

// Azure AI Foundry Integration (disabled)
param useTargetFoundry = false

param foundry = {
  subscriptionId: '00000000-0000-0000-0000-000000000000'
  resourceGroupName: 'placeholder'
  accountName: 'placeholder'
  projectName: 'placeholder'
}

