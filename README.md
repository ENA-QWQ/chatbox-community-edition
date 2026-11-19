# Chatbox Community Edition

A privacy-preserving, de-commercialized fork of
[chatboxai/chatbox](https://github.com/chatboxai/chatbox) — a desktop AI client
for Windows, macOS and Linux that works with your own model providers.

Distributed under the GNU GPL v3, same as upstream.

## Why this fork exists

Upstream Chatbox is a capable local-first client, but it ships with a commercial
layer: telemetry, an account/license system, subscription prompts, cloud
add-on services and server-driven marketing UI. The Community Edition strips
all of that out while keeping the client fully functional with your own API
keys.

**What is guaranteed removed:**

| Area | Removed |
| --- | --- |
| Telemetry | Sentry, Google Analytics (Measurement Protocol with device id), Plausible |
| Accounts | Chatbox AI sign-in, license keys, plan/quota tracking, token storage |
| Monetization | Upgrade prompts, free-plan claim funnels, expansion packs, sponsor components, funding links |
| Cloud add-ons | Built-in Chatbox AI search, cloud document parsing, subscription MCP servers, remote model catalog, remote config, background skill sync |
| Server-driven UI | Marketing dialogs, client notifications, cloud-hosted onboarding guide |
| Onboarding | Preset demo conversations (you start with an empty, local session list) |
| Distribution | Official auto-updater feed, S3/R2 publish target, anti-piracy hostname guard |

**What still works:**

- Multi-provider chat: OpenAI, Anthropic, Gemini, DeepSeek, Groq, OpenRouter,
  Ollama, LM Studio and any OpenAI-compatible endpoint
- Image generation through your own providers
- MCP servers (bring your own), skills marketplace (GitHub-based), agent mode
- Knowledge base and session RAG with your own embedding/rerank models
- Web search via Bing, Tavily, Bocha, Querit or a self-hosted SearXNG
- Local-first storage: conversations in IndexedDB/SQLite, knowledge bases in
  local SQLite files, settings in a local config file — nothing is synced
  anywhere

## Getting started

### Install

Download installers from the GitHub Releases page of this fork, or build from
source (below). Builds are unsigned; on Windows you will see a SmartScreen
warning — choose "More info" → "Run anyway".

### Configure a model

1. Open **Settings → Model Provider**
2. Add an API key for any provider (or point at a local Ollama / LM Studio)
3. Start chatting

There is no account step and nothing to sign into.

## Verification

The privacy claims above are enforced and testable, not just documented:

```bash
# Verify/re-apply all 52 Community Edition gates (idempotent)
./build-scripts/sanitize.sh           # macOS / Linux
pwsh ./build-scripts/sanitize.ps1     # Windows

# Prove a running build performs zero upstream/telemetry traffic
pnpm start:cdp                                   # dev build with CDP port 9333
node build-scripts/cdp-network-probe.mjs 45 9333 # expect external=0 denied=0
node build-scripts/cdp-ui-assert.mjs 9333        # expect no SaaS UI entries
```

All sanitization is implemented as small gates behind five switches in
`src/shared/ce-edition.ts`, marked with `[Chatbox CE]` in source.

## Building from source

Requirements: Node.js >= 22.13, pnpm >= 10.17.

```bash
pnpm install
pnpm dev             # development mode
pnpm run package     # package for the current platform (unsigned)
pnpm test:unit       # unit tests
```

Packaging uses electron-builder with the upstream S3 publish target removed and
a no-op Windows signing hook; artifacts land in `release/build/`.

## Continuous integration

`.github/workflows/` provides three pipelines:

- **build.yml** — on push/PR/manual: sanitizer gate → install → package for the
  runner platform → upload artifacts (Windows NSIS, macOS dmg, Linux
  AppImage/deb)
- **sync-upstream.yml** — daily cron: merges upstream `main`, re-applies the
  sanitizer, guards the publish config, type-checks, then tags and builds a
  pre-release (merge conflicts or lost gates fail loudly for manual handling)
- **release.yml** — on `ce-v*` tags: verify-only sanitizer gate + type check,
  then a full three-platform build published as a stable GitHub Release

## Keeping up with upstream

```bash
git fetch origin
git checkout main && git merge --ff-only origin/main
git checkout feature/community-edition && git merge main
./build-scripts/sanitize.sh     # re-verify gates; fix any FAIL by re-applying
pnpm exec tsc --noEmit && pnpm test:unit
```

The sanitizer is the safety net: if an upstream merge overwrites a gate, the
script (and CI) will catch it.

## Repository layout

```
src/
  main/       Electron main process
  preload/    preload bridge
  renderer/   React UI (routes, components, stores)
  shared/     shared logic, types, providers, CE switches
packages/
  chatbox-core/   framework-agnostic domain layer
  chatbox-react/  shared React hooks/stores
  chatbox-i18n/   translations
build-scripts/    sanitizer + CDP verification probes
.github/workflows build, sync, release pipelines
```

## License

[GPL-3.0](./LICENSE)

Based on [Chatbox](https://github.com/chatboxai/chatbox) by Bin Huang and
contributors. This fork carries no affiliation with, endorsement from, or
commercial relationship to the upstream project or its services.
