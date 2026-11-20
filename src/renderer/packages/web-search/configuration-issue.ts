import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import { type NativeWebSearchCredentialSources, resolveNativeWebSearchApiKey } from '@shared/services/native-web-search'
import type { WebSearchProviderValue } from './constants'

export type WebSearchReadinessSettings = NativeWebSearchCredentialSources & {
  extension: { webSearch: { provider: WebSearchProviderValue; searxngBaseUrl?: string } }
  licenseKey?: string
}

export type WebSearchConfigurationIssue =
  | 'chatbox-ai-sign-in'
  | 'provider-unavailable'
  | 'deepseek-api-key'
  | 'tavily-api-key'
  | 'bocha-api-key'
  | 'querit-api-key'
  | 'searxng-instance'

export function getWebSearchConfigurationIssue(
  settings: WebSearchReadinessSettings,
  provider: WebSearchProviderValue = settings.extension.webSearch.provider
): WebSearchConfigurationIssue | null {
  switch (provider) {
    case 'build-in':
      if (CE_DISABLE_REMOTE_CONTENT) {
        return 'provider-unavailable'
      }
      return settings.licenseKey ? null : 'chatbox-ai-sign-in'
    case 'searxng':
      return settings.extension.webSearch.searxngBaseUrl?.trim() ? null : 'searxng-instance'
    case 'bing':
      return null
    default:
      return resolveNativeWebSearchApiKey(settings, provider).trim() ? null : (`${provider}-api-key` as const)
  }
}
