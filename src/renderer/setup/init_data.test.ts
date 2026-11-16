import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { SessionMetaStorage } from '@/storage/SessionMetaStorage'
import { initData } from './init_data'

const metaStorage = vi.hoisted(() => ({
  getAllTotal: vi.fn(),
  createMany: vi.fn(),
}))

const sessionRepositoryMock = vi.hoisted(() => ({
  createSessionRows: vi.fn(),
}))

vi.mock('@/adapters/CurrentSessionRepository', () => ({
  CurrentSessionRepository: class {
    createSessionRows = sessionRepositoryMock.createSessionRows
  },
}))

vi.mock('@/packages/initial_data', () => ({
  defaultSessionsForCN: [],
  defaultSessionsForEN: [
    {
      id: 'default-session',
      name: 'Default Session',
      messages: [],
      type: 'chat',
    },
  ],
}))

vi.mock('@/platform', () => ({
  default: {
    getLocale: vi.fn(() => Promise.resolve('en')),
  },
}))

vi.mock('@/stores/sessionHelpers', () => ({
  getMetaStorage: vi.fn(() => Promise.resolve(metaStorage)),
  getSessionMeta: (session: { id: string; name: string; type: 'chat' | 'picture' }) => ({
    id: session.id,
    name: session.name,
    type: session.type,
  }),
}))

describe('initData', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    metaStorage.createMany.mockResolvedValue(undefined)
    sessionRepositoryMock.createSessionRows.mockResolvedValue(undefined)
  })

  // [Chatbox CE] initData is a no-op: the onboarding demo conversations are
  // Chatbox marketing content and are never seeded, so storage is not even
  // consulted.
  it('never consults storage or seeds default sessions', async () => {
    metaStorage.getAllTotal.mockResolvedValue(0)

    await initData()

    expect(metaStorage.getAllTotal).not.toHaveBeenCalled()
    expect(sessionRepositoryMock.createSessionRows).not.toHaveBeenCalled()
    expect(metaStorage.createMany).not.toHaveBeenCalled()
  })

  it('still resolves successfully when seeded data already exists', async () => {
    metaStorage.getAllTotal.mockResolvedValue(7)

    await expect(initData()).resolves.toBeUndefined()

    expect(sessionRepositoryMock.createSessionRows).not.toHaveBeenCalled()
    expect(metaStorage.createMany).not.toHaveBeenCalled()
  })
})

metaStorage satisfies Pick<SessionMetaStorage, 'getAllTotal' | 'createMany'>
