using '../../../main.bicep'

// ============================================================================
// HR Chat Agent - Key Vault + Foundry (if enabled) - Generated from Notebook
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
  businessUnit: 'HR'
  useCaseName: 'ChatAgent'
  environment: 'DEV'
}

param apiNameMapping = {
  LLM: ['universal-llm-api', 'azure-openai-api']
}

param services = [
  {
    code: 'LLM'
    endpointSecretName: 'HR-LLM-ENDPOINT'
    apiKeySecretName: 'HR-LLM-KEY'
    policyXml: loadTextContent('ai-product-policy.xml')
  }
]

param productTerms = 'Access Contract created from testing notebook - HR Chat Agent - Key Vault + Foundry (if enabled)'

// Azure AI Foundry Integration
param useTargetFoundry = true

param foundry = {
  subscriptionId: 'ad44bcb2-464c-463f-86b8-a89d43903cbf'
  resourceGroupName: 'foundry-nextgen'
  accountName: 'nextgen-project-2-resource'
  projectName: 'nextgen-project-2'
}

param foundryConfig = {
  connectionNamePrefix: ''
  deploymentInPath: 'false'
  isSharedToAll: false
  inferenceAPIVersion: ''
  deploymentAPIVersion: ''
  staticModels: []
  listModelsEndpoint: ''
  getModelEndpoint: ''
  deploymentProvider: ''
  customHeaders: {}
  authConfig: {}
}

