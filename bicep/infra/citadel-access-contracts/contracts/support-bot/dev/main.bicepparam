using '../../../main.bicep'

// ============================================================================
// Support Bot - Direct output (no Key Vault nor Foundry connection integration) - Generated from Notebook
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

param useTargetAzureKeyVault = false

param useCase = {
  businessUnit: 'Support'
  useCaseName: 'Bot'
  environment: 'DEV'
}

param apiNameMapping = {
  LLM: ['universal-llm-api', 'azure-openai-api']
}

param services = [
  {
    code: 'LLM'
    endpointSecretName: 'SUPPORT-LLM-ENDPOINT'
    apiKeySecretName: 'SUPPORT-LLM-KEY'
    policyXml: loadTextContent('ai-product-policy.xml')
  }
]

param productTerms = 'Access Contract created from testing notebook - Support Bot - Direct output (no Key Vault nor Foundry connection integration)'

// Azure AI Foundry Integration (disabled)
param useTargetFoundry = false

param foundry = {
  subscriptionId: '00000000-0000-0000-0000-000000000000'
  resourceGroupName: 'placeholder'
  accountName: 'placeholder'
  projectName: 'placeholder'
}

