// [Chatbox CE] the built-in Chatbox AI search provider is not offered; legacy
// configurations with provider='build-in' are reported as an unavailable
// provider instead of a sign-in prompt.
import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import type { WebSearchProviderValue } from './constants'

type WebSearchConfiguration = {
  provider: WebSearchProviderValue
  tavilyApiKey?: string
  bochaApiKey?: string
  queritApiKey?: string
  searxngBaseUrl?: string
}

export type WebSearchConfigurationIssue =
  | 'chatbox-ai-sign-in'
  | 'provider-unavailable'
  | 'tavily-api-key'
  | 'bocha-api-key'
  | 'querit-api-key'
  | 'searxng-instance'

export function getWebSearchConfigurationIssue(
  configuration: WebSearchConfiguration,
  licenseKey?: string
): WebSearchConfigurationIssue | null {
  switch (configuration.provider) {
    case 'build-in':
      // [Chatbox CE] never ask the user to sign in to Chatbox AI
      if (CE_DISABLE_REMOTE_CONTENT) {
        return 'provider-unavailable'
      }
      return licenseKey ? null : 'chatbox-ai-sign-in'
    case 'tavily':
      return configuration.tavilyApiKey ? null : 'tavily-api-key'
    case 'bocha':
      return configuration.bochaApiKey ? null : 'bocha-api-key'
    case 'querit':
      return configuration.queritApiKey ? null : 'querit-api-key'
    case 'searxng':
      return configuration.searxngBaseUrl?.trim() ? null : 'searxng-instance'
    case 'bing':
      return null
  }
}
