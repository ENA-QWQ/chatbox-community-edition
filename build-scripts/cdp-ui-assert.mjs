#!/usr/bin/env node
/**
 * [Chatbox CE] UI assertion probe.
 * Connects to the CDP page target and verifies, in the live app:
 *   1. window.plausible / window.gtag are undefined (analytics scripts absent)
 *   2. The settings navigation renders no "Chatbox AI" account entry
 *   3. The settings advanced page renders no "Error Reporting" switch
 * Usage: node build-scripts/cdp-ui-assert.mjs [cdpPort]
 */

const CDP_PORT = Number(process.argv[2]) || 9333
const CDP_HTTP = `http://127.0.0.1:${CDP_PORT}`

async function fetchJson(url) {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`${url} -> ${res.status}`)
  return res.json()
}

async function main() {
  const targets = await fetchJson(`${CDP_HTTP}/json`).catch((e) => {
    console.error(`ASSERT-ERROR: CDP unreachable (${e.message})`)
    process.exit(2)
  })
  const page = targets.find((t) => t.type === 'page' && t.webSocketDebuggerUrl)
  if (!page) {
    console.error('ASSERT-ERROR: no page target')
    process.exit(2)
  }

  const ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true })
    ws.addEventListener('error', reject, { once: true })
    setTimeout(() => reject(new Error('ws timeout')), 10_000)
  })

  let msgId = 0
  const pending = new Map()
  ws.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data)
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg)
      pending.delete(msg.id)
    }
  })
  const call = (method, params) =>
    new Promise((resolve) => {
      const id = ++msgId
      pending.set(id, resolve)
      ws.send(JSON.stringify({ id, method, params: params ?? {} }))
    })

  await call('Runtime.enable')
  const evaluate = async (expression) => {
    const res = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })
    return res.result?.result?.value
  }

  const failures = []
  const check = (name, ok, detail = '') => {
    console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${name}${detail ? ` — ${detail}` : ''}`)
    if (!ok) failures.push(name)
  }

  // 1. Analytics globals absent
  const plausible = await evaluate("typeof window.plausible")
  check('window.plausible is undefined', plausible === 'undefined', `typeof=${plausible}`)
  const gtag = await evaluate("typeof window.gtag")
  check('window.gtag is undefined', gtag === 'undefined', `typeof=${gtag}`)
  const gaScript = await evaluate(
    "Array.from(document.querySelectorAll('script[src]')).some((s) => /googletagmanager|plausible|google-analytics/.test(s.src))"
  )
  check('no analytics <script> tags in DOM', gaScript === false)

  // 2. Navigate to settings and check the nav
  await evaluate("window.location.hash = ''")
  // The app uses TanStack router with history routing on desktop (file://) or web paths.
  await evaluate(`(() => { try { history.pushState({}, '', '/settings'); window.dispatchEvent(new PopStateEvent('popstate')); } catch (e) {} })()`)
  await new Promise((r) => setTimeout(r, 2500))
  const bodyText = (await evaluate('document.body.innerText')) || ''

  const hasChatboxAIAccountEntry = /Chatbox AI/.test(bodyText) && /Not activated|Activated/.test(bodyText)
  check('no Chatbox AI account card in settings index', !hasChatboxAIAccountEntry)

  const navHasAccountGroup = (await evaluate(
    "Array.from(document.querySelectorAll('a')).some((a) => a.getAttribute('href')?.includes('/settings/chatbox-ai'))"
  ))
  check('no /settings/chatbox-ai links in sidebar', navHasAccountGroup === false)

  // 3. Advanced page: no Error Reporting switch
  await evaluate(`(() => { try { history.pushState({}, '', '/settings/advanced'); window.dispatchEvent(new PopStateEvent('popstate')); } catch (e) {} })()`)
  await new Promise((r) => setTimeout(r, 2500))
  const advText = (await evaluate('document.body.innerText')) || ''
  check('no Error Reporting switch on advanced page', !/Error Reporting/.test(advText))

  ws.close()
  console.log('')
  if (failures.length > 0) {
    console.log(`ASSERT-VERDICT: FAIL — ${failures.length} check(s): ${failures.join('; ')}`)
    process.exit(1)
  }
  console.log('ASSERT-VERDICT: PASS — UI is free of SaaS entries and analytics hooks.')
  process.exit(0)
}

main().catch((e) => {
  console.error(`ASSERT-ERROR: ${e.stack || e.message}`)
  process.exit(2)
})
