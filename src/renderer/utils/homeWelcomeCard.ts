// [Chatbox CE] suppress the login / purchase welcome card entirely: the card is
// a Chatbox AI login/purchase funnel and does not apply to the Community Edition.
import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import {
  getHomeWelcomeCardMode as getHomeWelcomeCardModeCore,
  type HomeWelcomeCardMode,
} from '@chatbox/core/application/settings'

export function getHomeWelcomeCardMode(params: {
  providerCount: number
  isLoggedIn: boolean
  hasLicense: boolean
  hasExpiredLicense: boolean
  hideForStoreReview?: boolean
}): HomeWelcomeCardMode {
  if (CE_DISABLE_REMOTE_CONTENT) {
    return 'none'
  }
  return getHomeWelcomeCardModeCore(params)
}

export type { HomeWelcomeCardMode }
