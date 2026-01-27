using '../../../main.bicep'

// ============================================================================
// HR Chat Agent - Key Vault + Foundry (if enabled) - Generated from Notebook
// ============================================================================

param apim = {
  subscriptionId: 'ad44bcb2-464c-463f-86b8-a89d43903cbf'
  resourceGroupName: 'rg-ai-hub-citadel-test'
  name: 'apim-cbocvfdlle56y'
}

param keyVault = {
  subscriptionId: 'ad44bcb2-464c-463f-86b8-a89d43903cbf'
  resourceGroupName: 'rg-ai-hub-citadel-test'
  name: 'kv-cbocvfdlle56y'
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
  resourceGroupName: 'rg-ai-hub-citadel-test'
  accountName: 'aif-cbocvfdlle56y-0'
  projectName: 'citadel-governance-project'
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

