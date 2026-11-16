/**
 * [Chatbox CE] Community Edition master switches.
 *
 * Chatbox Community Edition (GPLv3) removes all SaaS dependencies:
 * telemetry (Sentry / Google Analytics / Plausible), the Chatbox AI
 * account/license/quota cloud, remote content channels (marketing dialogs,
 * client notifications, copilot usage reporting) and the official
 * auto-updater feed.
 *
 * Everything is gated with these compile-time constants instead of deleting
 * upstream code, so merging upstream updates stays cheap. Grep for the
 * `[Chatbox CE]` marker to find every gate. Flip a constant to `false` to
 * restore the corresponding upstream behavior.
 *
 * This module must stay dependency-free (leaf module) — it is imported by
 * both the Electron main process and the renderer.
 */

/** Master switch for the whole Community Edition sanitization. */
export const CE_EDITION: boolean = true

/** Disable all telemetry/analytic outbound traffic (Sentry, GA4, Plausible, JK). */
export const CE_DISABLE_TELEMETRY: boolean = CE_EDITION

/** Disable remote content channels (dialogs, client notifications, remote config, usage reports). */
export const CE_DISABLE_REMOTE_CONTENT: boolean = CE_EDITION

/** Disable the official auto-updater feed (community builds distribute via their own channel). */
export const CE_DISABLE_OFFICIAL_UPDATER: boolean = CE_EDITION
