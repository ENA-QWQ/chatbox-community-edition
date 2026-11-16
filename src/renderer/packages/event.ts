import type { AnalyticsEventParams } from '@shared/analytics'
// [Chatbox CE] telemetry master switch
import { CE_DISABLE_TELEMETRY } from '@shared/ce-edition'
import platform from '@/platform'
import { settingsStore } from '@/stores/settingsStore'

export function trackingEvent(name: string, params: AnalyticsEventParams = {}) {
  // [Chatbox CE] all analytics events are dropped in the Community Edition.
  if (CE_DISABLE_TELEMETRY) {
    return
  }
  const allowReportingAndTracking = settingsStore.getState().allowReportingAndTracking
  if (!allowReportingAndTracking) {
    return
  }
  platform.trackingEvent(name, params)
}
