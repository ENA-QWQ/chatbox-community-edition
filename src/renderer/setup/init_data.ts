import { SessionHeaderSchema } from '@shared/types'
// [Chatbox CE] preset demo conversations are not seeded
import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import { sessionRepository } from '@/app/renderer-application'
import { defaultSessionsForCN, defaultSessionsForEN } from '@/packages/initial_data'
import platform from '@/platform'
import { getMetaStorage, getSessionMeta } from '@/stores/sessionHelpers'
import { createSessionMetaRecordsFromLegacyList } from '@/utils/session-utils'

export async function initData() {
  await initSessionsIfNeeded()
}

async function initSessionsIfNeeded() {
  // [Chatbox CE] the onboarding demo conversations are Chatbox marketing
  // content; the Community Edition starts with an empty session list.
  if (CE_DISABLE_REMOTE_CONTENT) {
    return
  }
  const metaStorage = await getMetaStorage()
  const total = await metaStorage.getAllTotal()
  if (total > 0) {
    return
  }

  const lang = await platform.getLocale().catch(() => 'en')
  const defaultSessions = lang.startsWith('zh') ? defaultSessionsForCN : defaultSessionsForEN

  for (const session of defaultSessions) {
    await sessionRepository.createSessionRows(SessionHeaderSchema.parse(session), session.messages)
  }

  const records = createSessionMetaRecordsFromLegacyList(defaultSessions.map(getSessionMeta))

  await metaStorage.createMany(records)
}
