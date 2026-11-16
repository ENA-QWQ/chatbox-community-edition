import * as Sentry from '@sentry/node'
import { app } from 'electron'
// [Chatbox CE] telemetry master switch
import { CE_DISABLE_TELEMETRY } from '../../shared/ce-edition'
import type { SentryAdapter, SentryScope } from '../../shared/utils/sentry_adapter'
import { createSentryEventProcessor, normalizeErrorForSentry } from '../../shared/utils/sentry_policy'
import { getSettings, store } from '../store-node'

const processSentryEvent = createSentryEventProcessor({
  dedupeOriginalExceptions: true,
  normalSampleRate: 0.2,
  source: 'main',
})

let sentryInitialized = false

function initSentry(): boolean {
  // [Chatbox CE] Sentry is never initialized in the Community Edition.
  if (CE_DISABLE_TELEMETRY) {
    return false
  }
  if (sentryInitialized) {
    return true
  }

  const settings = getSettings()
  if (!settings.allowReportingAndTracking) {
    return false
  }

  const version = app.getVersion()
  Sentry.init({
    dsn: 'https://eca691c5e01ebfa05958fca1fcb487a9@sentry.midway.run/697',
    integrations: [],
    environment: process.env.NODE_ENV || 'development',
    // Error sampling is priority-aware in beforeSend.
    sampleRate: 1.0,
    tracesSampler(samplingContext) {
      // For traces related to knowledge-base operations, always sample
      const isKnowledgeBaseTrace =
        samplingContext.tags?.component === 'knowledge-base-file' ||
        samplingContext.tags?.component === 'knowledge-base-db' ||
        samplingContext.tags?.component === 'knowledge-base'

      if (isKnowledgeBaseTrace) {
        return 1.0 // 100% sampling for knowledge-base traces
      }

      return 0.1 // 10% sampling for other traces
    },
    release: version,
    // 设置全局标签
    initialScope: {
      tags: {
        platform: 'desktop',
        app_version: version,
        error_source: 'main',
      },
    },
    beforeSend(event, hint) {
      if (!getSettings().allowReportingAndTracking) {
        return null
      }
      return processSentryEvent(event, hint)
    },
  })
  sentryInitialized = true
  return true
}

initSentry()

store.onDidAnyChange((settings, previousSettings) => {
  const reportingEnabled = settings?.settings?.allowReportingAndTracking === true
  const reportingWasEnabled = previousSettings?.settings?.allowReportingAndTracking === true
  if (reportingEnabled === reportingWasEnabled) {
    return
  }

  if (reportingEnabled) {
    initSentry()
  } else {
    sentryInitialized = false
    void Sentry.close(2000)
  }
})

/**
 * 主进程的 Sentry 适配器实现
 * 使用 @sentry/node 进行错误上报
 */
export class MainSentryAdapter implements SentryAdapter {
  captureException(error: unknown): void {
    // [Chatbox CE] never report when the SDK was not initialized
    if (CE_DISABLE_TELEMETRY || !sentryInitialized) {
      return
    }
    Sentry.captureException(normalizeErrorForSentry(error))
  }

  withScope(callback: (scope: SentryScope) => void): void {
    // [Chatbox CE] never report when the SDK was not initialized
    if (CE_DISABLE_TELEMETRY || !sentryInitialized) {
      return
    }
    Sentry.withScope((sentryScope) => {
      const scope: SentryScope = {
        setTag(key: string, value: string): void {
          sentryScope.setTag(key, value)
        },
        setExtra(key: string, value: unknown): void {
          sentryScope.setExtra(key, value)
        },
      }
      callback(scope)
    })
  }
}

export const sentry = new MainSentryAdapter()

export function flushSentry(timeout: number): Promise<boolean> {
  // [Chatbox CE] nothing to flush when the SDK was not initialized
  if (CE_DISABLE_TELEMETRY || !sentryInitialized) {
    return Promise.resolve(true)
  }
  return Sentry.flush(timeout)
}
