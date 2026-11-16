/**
 * Guide API utilities for communicating with the backend guide chat endpoint
 */

// [Chatbox CE] the guide chat endpoint is a billed official-server call; it is
// never reached in the Community Edition (see sendGuideMessage guard).
import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import { getAPIOrigin } from '@/packages/remote'
import { apiRequest } from '@/utils/request'
import { USE_LOCAL_API } from '@/variables'

const GUIDE_API_PATH = '/v1/guide/chat'

function getGuideAPIURL() {
  if (USE_LOCAL_API) {
    return `http://localhost:8011${GUIDE_API_PATH}`
  }
  return `${getAPIOrigin()}${GUIDE_API_PATH}`
}

export interface GuideMessage {
  role: 'user' | 'assistant'
  content: string
}

export interface GuideRequest {
  messages: GuideMessage[]
  device_id: string
  onboarding_step?: 'greeting' | 'selection' | 'login_flow' | 'completed'
  is_logged_in?: boolean
  stream: boolean
}

/**
 * Send a message to the guide chat API
 * Returns a streaming response that can be parsed with AI SDK's readUIMessageStream
 */
export async function sendGuideMessage(
  messages: GuideMessage[],
  deviceId: string,
  options?: {
    onboardingStep?: GuideRequest['onboarding_step']
    isLoggedIn?: boolean
    signal?: AbortSignal
  }
): Promise<Response> {
  // [Chatbox CE] hard stop: never call api.chatboxai.app/v1/guide/chat.
  if (CE_DISABLE_REMOTE_CONTENT) {
    throw new Error('[Chatbox CE] the onboarding guide chat API is disabled in the Community Edition')
  }
  const body: GuideRequest = {
    messages,
    device_id: deviceId,
    onboarding_step: options?.onboardingStep,
    is_logged_in: options?.isLoggedIn,
    stream: true,
  }

  const response = await apiRequest.post(
    getGuideAPIURL(),
    {
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
    },
    JSON.stringify(body),
    {
      useProxy: false,
      signal: options?.signal,
      // Guide API POST triggers a billable AI streaming call upstream;
      // a transient network error after the server has already processed
      // the request would double-charge if we retried.
      retry: 0,
    }
  )

  return response
}
