import { describe, expect, it } from 'vitest'

import { getHomeWelcomeCardMode } from './homeWelcomeCard'

// [Chatbox CE] the Community Edition always suppresses the welcome card, so the
// upstream mode matrix collapses to a single outcome.
describe('getHomeWelcomeCardMode (CE)', () => {
  it('returns "none" when providerCount > 0', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 1,
        isLoggedIn: false,
        hasLicense: false,
        hasExpiredLicense: false,
      })
    ).toBe('none')
  })

  it('returns "none" when hasLicense is true (even if not logged in)', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 0,
        isLoggedIn: false,
        hasLicense: true,
        hasExpiredLicense: false,
      })
    ).toBe('none')
  })

  it('returns "none" when logged in but no license and no providers', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 0,
        isLoggedIn: true,
        hasLicense: false,
        hasExpiredLicense: false,
      })
    ).toBe('none')
  })

  it('returns "none" when logged in, no license, and hasExpiredLicense is true', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 0,
        isLoggedIn: true,
        hasLicense: false,
        hasExpiredLicense: true,
      })
    ).toBe('none')
  })

  it('returns "none" when not logged in, no license, no providers', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 0,
        isLoggedIn: false,
        hasLicense: false,
        hasExpiredLicense: false,
      })
    ).toBe('none')
  })

  it('returns "none" during store review even when login card would otherwise show', () => {
    expect(
      getHomeWelcomeCardMode({
        providerCount: 0,
        isLoggedIn: false,
        hasLicense: false,
        hasExpiredLicense: false,
        hideForStoreReview: true,
      })
    ).toBe('none')
  })
})
