#!/usr/bin/env node
/**
 * [Chatbox CE] CDP network probe.
 *
 * Attaches to the Electron renderer via the Chrome DevTools Protocol
 * (--remote-debugging-port=9333, see `pnpm start:cdp`), records every
 * outgoing HTTP(S) request for a configurable duration, then asserts the
 * Community Edition privacy bar:
 *
 *   DENY: chatboxai.app / chatboxai.com / ai-chatbox.com / chatboxapp.xyz /
 *         chatbox.run / midway.run / google-analytics.com / googletagmanager.com /
 *         plausible / vibedrop / sentry
 *
 * Usage: node build-scripts/cdp-network-probe.mjs [durationSeconds] [cdpPort]
 */

const DURATION_MS = (Number(process.argv[2]) || 45) * 1000
const CDP_PORT = Number(process.argv[3]) || 9333
const CDP_HTTP = `http://127.0.0.1:${CDP_PORT}`

const DENY_PATTERNS = [
  /chatboxai\.app/i,
  /chatboxai\.com/i,
  /ai-chatbox\.com/i,
  /chatboxapp\.xyz/i,
  /chatbox\.run/i,
  /midway\.run/i,
  /google-analytics\.com/i,
  /googletagmanager\.com/i,
  /plausible/i,
  /vibedrop/i,
  /sentry/i,
]

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function fetchJson(url) {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`${url} -> ${res.status}`)
  return res.json()
}

async function main() {
  // 1. Find the app window targets.
  let targets
  try {
    targets = await fetchJson(`${CDP_HTTP}/json`)
  } catch (error) {
    console.error(`PROBE-ERROR: cannot reach CDP at ${CDP_HTTP} (${error.message}). Is the app running with --remote-debugging-port?`)
    process.exit(2)
  }
  const pages = targets.filter((t) => t.type === 'page' && t.webSocketDebuggerUrl)
  if (pages.length === 0) {
    console.error('PROBE-ERROR: no page targets with webSocketDebuggerUrl found.', JSON.stringify(targets.map((t) => t.type)))
    process.exit(2)
  }
  console.log(`PROBE: found ${pages.length} page target(s): ${pages.map((p) => p.title || p.url).join(' | ')}`)

  const requests = new Map() // requestId -> { url, method, type }
  const sockets = []
  let attached = 0

  for (const target of pages) {
    try {
      const ws = new WebSocket(target.webSocketDebuggerUrl)
      await new Promise((resolve, reject) => {
        ws.addEventListener('open', resolve, { once: true })
        ws.addEventListener('error', reject, { once: true })
        setTimeout(() => reject(new Error('ws open timeout')), 10_000)
      })
      sockets.push(ws)
      let msgId = 0
      const pending = new Map()
      const call = (method, params) =>
        new Promise((resolve) => {
          const id = ++msgId
          pending.set(id, resolve)
          ws.send(JSON.stringify({ id, method, params: params ?? {} }))
        })
      ws.addEventListener('message', (event) => {
        const msg = JSON.parse(event.data)
        if (msg.id && pending.has(msg.id)) {
          pending.get(msg.id)(msg.result)
          pending.delete(msg.id)
          return
        }
        if (msg.method === 'Network.requestWillBeSent') {
          const { requestId, request } = msg.params
          requests.set(`${target.id}:${requestId}`, { url: request.url, method: request.method, type: msg.params.type })
        }
      })
      await call('Network.enable', { maxTotalBufferSize: 10_000_000, maxResourceBufferSize: 5_000_000 })
      // The dev app also runs service-worker-free page loads only; extra targets (workers) are ignored.
      attached += 1
    } catch (error) {
      console.warn(`PROBE-WARN: could not attach to target ${target.url}: ${error.message}`)
    }
  }

  if (attached === 0) {
    console.error('PROBE-ERROR: failed to attach Network domain to any target.')
    process.exit(2)
  }

  console.log(`PROBE: Network domain attached to ${attached} target(s); recording for ${DURATION_MS / 1000}s...`)
  await sleep(DURATION_MS)

  for (const ws of sockets) {
    try {
      ws.close()
    } catch {
      /* ignore */
    }
  }

  // 2. Classify requests. Localhost requests (Vite dev server module loads,
  // static assets) are never telemetry targets — deny rules apply to
  // non-local hosts only.
  const isLocal = (url) => {
    try {
      return ['localhost', '127.0.0.1'].includes(new URL(url).hostname)
    } catch {
      return false
    }
  }
  const all = [...requests.values()]
  const denied = all.filter((r) => !isLocal(r.url) && DENY_PATTERNS.some((pattern) => pattern.test(r.url)))
  const external = all.filter((r) => !isLocal(r.url))

  console.log('')
  console.log(`PROBE-RESULT: total=${all.length} external=${external.length} denied=${denied.length}`)
  if (external.length > 0) {
    console.log('--- external requests observed ---')
    for (const r of external.slice(0, 50)) console.log(`  [${r.method}] ${r.url}`)
  }
  if (denied.length > 0) {
    console.log('--- PRIVACY VIOLATIONS ---')
    for (const r of denied) console.log(`  [${r.method}] ${r.url}`)
    console.log('PROBE-VERDICT: FAIL — telemetry/official endpoints were contacted.')
    process.exit(1)
  }
  console.log('PROBE-VERDICT: PASS — no requests to telemetry or official Chatbox endpoints.')
  process.exit(0)
}

main().catch((error) => {
  console.error(`PROBE-ERROR: ${error.stack || error.message}`)
  process.exit(2)
})
