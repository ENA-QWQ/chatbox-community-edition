#!/usr/bin/env bash
# =============================================================================
# [Chatbox CE] Sanitizer — idempotent privacy/telemetry sanitization for the
# Chatbox Community Edition (GPLv3 fork of chatboxai/chatbox).
#
# Usage:
#   ./build-scripts/sanitize.sh                 # verify + apply
#   ./build-scripts/sanitize.sh --verify-only   # verify only
#   ./build-scripts/sanitize.sh --hard-endpoints  # also pin API origin to 127.0.0.1:1
#
# Convention: every CE code edit is marked with the literal marker
# `[Chatbox CE]`. The verifier keys off that marker. See sanitize.ps1 for the
# Windows twin of this script (they must stay in sync).
# =============================================================================
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERIFY_ONLY=0
HARD_ENDPOINTS=0
for arg in "$@"; do
  case "$arg" in
    --verify-only) VERIFY_ONLY=1 ;;
    --hard-endpoints) HARD_ENDPOINTS=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

FAILURES=0
ACTIONS=()

check() { # check <name> <passed:0/1> <detail>
  local name="$1" passed="$2" detail="${3:-}"
  if [ "$passed" -eq 1 ]; then
    printf '  [PASS] %s\n' "$name"
    [ -n "$detail" ] && printf '         %s\n' "$detail"
  else
    FAILURES=$((FAILURES + 1))
    printf '  [FAIL] %s\n' "$name" >&2
    [ -n "$detail" ] && printf '         %s\n' "$detail" >&2
  fi
}

marker_in_file() { # marker_in_file <relpath> <marker>
  local file="$REPO_ROOT/$1"
  [ -f "$file" ] && grep -qF -- "$2" "$file"
}

echo ""
echo "=== [Chatbox CE] sanitize run — repo: $REPO_ROOT ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Verify the code gates (marker-based)
# ---------------------------------------------------------------------------
check "CE master switch module exists"      "$(marker_in_file src/shared/ce-edition.ts 'CE_EDITION' && echo 1 || echo 0)" "src/shared/ce-edition.ts"
check "Renderer telemetry init chain gated" "$(marker_in_file src/renderer/app/bootstrapRenderer.ts 'CE_DISABLE_TELEMETRY' && echo 1 || echo 0)"
check "Renderer API-origin probing gated"   "$(marker_in_file src/renderer/app/bootstrapRenderer.ts 'proactive probing of official Chatbox API origins' && echo 1 || echo 0)"
check "Main-process Sentry gated"           "$(marker_in_file src/main/adapters/sentry.ts 'CE_DISABLE_TELEMETRY' && echo 1 || echo 0)"
check "GA Measurement-Protocol IPC gated"   "$(marker_in_file src/main/main.ts 'CE_DISABLE_TELEMETRY' && echo 1 || echo 0)"
check "Renderer analytics wrapper gated"    "$(marker_in_file src/renderer/packages/event.ts 'CE_DISABLE_TELEMETRY' && echo 1 || echo 0)"
check "Web gtag undefined guard"            "$(marker_in_file src/renderer/platform/web_platform.ts 'gtag.js is not loaded' && echo 1 || echo 0)"
check "Official update check (web) gated"   "$(marker_in_file src/renderer/hooks/useVersion.ts 'CE_DISABLE_OFFICIAL_UPDATER' && echo 1 || echo 0)"
check "Official updater (main) gated"       "$(marker_in_file src/main/app-updater.ts 'CE_DISABLE_OFFICIAL_UPDATER' && echo 1 || echo 0)"
check "Remote content channels gated"       "$(marker_in_file src/renderer/routes/__root.tsx 'CE_DISABLE_REMOTE_CONTENT' && echo 1 || echo 0)"
check "Remote dialog / notifications gated" "$(marker_in_file src/renderer/routes/__root.tsx 'RemoteDialogWindow' && echo 1 || echo 0)"
check "Builtin-skill backend sync gated"    "$(marker_in_file src/main/skills/builtin-sync.ts 'remote builtin-skill sync is disabled' && echo 1 || echo 0)"
check "Telemetry consent defaults to false" "$(marker_in_file packages/chatbox-core/src/domain/settings/settings-defaults.ts 'allowReportingAndTracking: false' && echo 1 || echo 0)"
check "Document parser defaults to local"   "$(marker_in_file packages/chatbox-core/src/domain/settings/settings-defaults.ts "type: 'local'" && echo 1 || echo 0)"
check "Vibedrop not enabled by default"     "$(marker_in_file src/shared/types/skills.ts 'Vibedrop is a third-party SaaS' && echo 1 || echo 0)"
check "Error Reporting switch removed (UI)" "$(marker_in_file src/renderer/routes/settings/advanced.tsx 'Error Reporting switch is removed' && echo 1 || echo 0)"
check "Account > Chatbox AI nav removed"    "$(marker_in_file src/renderer/components/settings/settingsNav.tsx 'Account > Chatbox AI' && echo 1 || echo 0)"
check "Chatbox AI settings card removed"    "$(marker_in_file src/renderer/routes/settings/route.tsx 'Chatbox AI account card removed' && echo 1 || echo 0)"
check "Free-license claim banner removed"   "$(marker_in_file src/renderer/routes/settings/web-search.tsx 'free-license claim banner removed' && echo 1 || echo 0)"
check "Cloud parser option filtered (UI)"   "$(marker_in_file src/renderer/components/settings/DocumentParserSettings.tsx 'Chatbox AI cloud parser is not offered' && echo 1 || echo 0)"
check "Chatbox AI Search filtered (slots)"  "$(marker_in_file src/renderer/routes/settings/default-models.tsx 'Chatbox AI Search) provider is not offered' && echo 1 || echo 0)"
check "Remote model catalog gated"          "$(marker_in_file src/renderer/hooks/useChatboxAIModels.ts 'never fetch the Chatbox AI model catalog' && echo 1 || echo 0)"
check "Free-trial banner removed (errors)"  "$(marker_in_file src/renderer/components/chat/GenericMessageError.tsx 'Chatbox AI free trial banner removed' && echo 1 || echo 0)"
check "KB cloud-parsing suggestion removed" "$(marker_in_file src/renderer/components/knowledge-base/KnowledgeBaseDocuments.tsx 'never suggest Chatbox AI cloud parsing' && echo 1 || echo 0)"
check "Welcome purchase funnel suppressed"  "$(marker_in_file src/renderer/utils/homeWelcomeCard.ts 'suppress the login / purchase welcome card' && echo 1 || echo 0)"
check "Official check-update link removed"  "$(marker_in_file src/renderer/components/DbSchemaGuardDialog.tsx 'official check-update redirect link removed' && echo 1 || echo 0)"
check "Menu website link replaced"          "$(marker_in_file src/main/menu.ts 'official website replaced' && echo 1 || echo 0)"
check "About page links neutralized"        "$(marker_in_file src/renderer/routes/about.tsx 'official privacy/terms links removed' && echo 1 || echo 0)"
check "About updater links gated"           "$(marker_in_file src/renderer/routes/about.tsx 'CE_DISABLE_OFFICIAL_UPDATER' && echo 1 || echo 0)"
check "Chatbox AI hidden from provider list" "$(marker_in_file src/renderer/components/settings/provider/ProviderList.tsx 'is never listed' && echo 1 || echo 0)"
check "Chatbox AI Search filtered (settings)" "$(marker_in_file src/renderer/routes/settings/web-search.tsx 'filtered out of the provider list' && echo 1 || echo 0)"
check "Builtin subscription MCP removed"    "$(marker_in_file packages/chatbox-core/src/mcp/builtin.ts 'metered by Chatbox AI license keys' && echo 1 || echo 0)"
check "Settings landing no longer login page" "$(marker_in_file src/renderer/routes/settings/index.tsx 'no longer redirects to the Chatbox AI login' && echo 1 || echo 0)"
check "License banner removed (chat errors)"  "$(marker_in_file src/renderer/components/chat/GenericMessageError.tsx 'license banner removed' && echo 1 || echo 0)"
check "KB login banner removed"               "$(marker_in_file src/renderer/components/knowledge-base/KnowledgeBase.tsx 'knowledge-base login banner removed' && echo 1 || echo 0)"
check "InputBox search panel filtered"        "$(marker_in_file src/renderer/components/InputBox/AgentModePanel.tsx 'not offered in the panel' && echo 1 || echo 0)"
check "MCP builtin section removed (page)"    "$(marker_in_file src/renderer/routes/settings/mcp.tsx 'Builtin subscription MCP servers section removed' && echo 1 || echo 0)"
check "Preset demo conversations not seeded"  "$(marker_in_file src/renderer/setup/init_data.ts 'preset demo conversations are not seeded' && echo 1 || echo 0)"
check "KB form parser option filtered"        "$(marker_in_file src/renderer/components/knowledge-base/KnowledgeBaseForm.tsx 'cloud parser / provider-mode options removed' && echo 1 || echo 0)"
check "KB remote model config gated"          "$(marker_in_file src/renderer/components/knowledge-base/KnowledgeBase.tsx 'remote Chatbox AI model config is not fetched' && echo 1 || echo 0)"
check "Onboarding guide auto-navigate gated"  "$(marker_in_file src/renderer/routes/__root.tsx 'onboarding guide is a cloud chat funnel' && echo 1 || echo 0)"
check "Guide chat API hard-stopped"           "$(marker_in_file src/renderer/routes/guide/-utils/guideApi.ts 'never call api.chatboxai.app/v1/guide/chat' && echo 1 || echo 0)"
check "Sidebar Help button repointed"         "$(marker_in_file src/renderer/Sidebar.tsx 'cloud sales funnel; open the project instead' && echo 1 || echo 0)"
check "Parser slot filtered (default-models)" "$(marker_in_file src/renderer/routes/settings/default-models.tsx 'cloud parser is not offered in slot selectors' && echo 1 || echo 0)"
check "Web-search issue neutralized (CE)"     "$(marker_in_file src/renderer/packages/web-search/configuration-issue.ts 'never ask the user to sign in to Chatbox AI' && echo 1 || echo 0)"
check "Search banner neutral copy"            "$(marker_in_file src/renderer/components/InputBox/WebSearchUnavailableBanner.tsx 'provider-unavailable' && echo 1 || echo 0)"
check "Tool sign-in card removed"             "$(marker_in_file src/renderer/components/message-parts/ToolUnavailableCard.tsx 'sign-in card is never shown' && echo 1 || echo 0)"
check "Attachment parser brand hidden"        "$(marker_in_file src/renderer/components/InputBox/Attachments.tsx 'legacy cloud-parsed attachments show no parser brand' && echo 1 || echo 0)"
check "Parser descriptions neutralized"       "$(marker_in_file src/renderer/components/settings/DocumentParserSettings.tsx 'descriptions no longer steer users toward Chatbox AI' && echo 1 || echo 0)"
check "KB subscription info card removed"     "$(marker_in_file src/renderer/components/knowledge-base/KnowledgeBaseForm.tsx 'Chatbox AI subscription info card is not shown' && echo 1 || echo 0)"

# ---------------------------------------------------------------------------
# 2. Delete upstream leaf files / directories (idempotent)
# ---------------------------------------------------------------------------
remove_path() { # remove_path <relpath> <reason>
  local rel="$1" reason="$2"
  local full="$REPO_ROOT/$rel"
  if [ -e "$full" ]; then
    case "$full" in
      "$REPO_ROOT"/*) ;;
      *) echo "Refusing to delete outside repo: $full" >&2; exit 1 ;;
    esac
    if [ "$VERIFY_ONLY" -eq 1 ]; then
      check "Should be absent: $rel" 0 "present; run without --verify-only to remove"
    else
      rm -rf -- "$full"
      ACTIONS+=("Deleted $rel — $reason")
      check "Absent: $rel" 1 "removed by this run"
    fi
  else
    check "Absent: $rel" 1 "already removed"
  fi
}

remove_path "src/renderer/setup/protect.ts" "Anti-piracy domain guard (dormant upstream code)"
remove_path "team-sharing" "Team-sharing docker docs (removed per CE policy)"

# ---------------------------------------------------------------------------
# 3. Re-apply the index.html analytics strip (idempotent)
# ---------------------------------------------------------------------------
INDEX_HTML="src/renderer/index.html"
if [ ! -f "$INDEX_HTML" ]; then
  check "index.html exists" 0 "$INDEX_HTML"
elif grep -qF '[Chatbox CE]' "$INDEX_HTML"; then
  check "index.html analytics strip present" 1 "CE marker found"
elif grep -q 'googletagmanager.com/gtag' "$INDEX_HTML" || grep -q 'plausible.midway.run' "$INDEX_HTML"; then
  # Upstream merge restored the tags — strip the whole GA + Plausible block again.
  python3 - "$INDEX_HTML" <<'PYEOF' && ACTION_INDEX=1 || ACTION_INDEX=0
import re, sys
path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    html = f.read()
pattern = re.compile(
    r'\s*<!-- Google tag \(gtag\.js\) -->.*?</script>\s*'
    r'<script>\s*window\.plausible =.*?</script>\s*'
    r'<script>\s*window\.dataLayer = window\.dataLayer \|\| \[\];.*?'
    r'gtag\("js", new Date\(\)\);\s*// gtag\(\'config\', \'G-B365F44W6E\'\);\s*</script>',
    re.S,
)
replacement = (
    '\n    <!-- [Chatbox CE] Google Analytics (gtag.js) and Plausible script tags removed.\n'
    '         window.gtag / window.plausible stay undefined, so every tracking wrapper\n'
    '         in the renderer takes its no-op path. -->\n'
)
patched, n = pattern.subn(replacement, html, count=1)
if n:
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(patched)
sys.exit(0 if n else 1)
PYEOF
  if [ "${ACTION_INDEX:-0}" -eq 1 ] && [ "$VERIFY_ONLY" -eq 0 ]; then
    ACTIONS+=("Stripped GA/Plausible tags from $INDEX_HTML (re-applied after upstream merge)")
    check "index.html analytics strip" 1 "was restored upstream; re-stripped"
  elif [ "$VERIFY_ONLY" -eq 1 ]; then
    check "index.html analytics strip" 0 "tags restored upstream; run without --verify-only to re-strip"
  else
    check "index.html analytics strip" 0 "python3 re-strip failed — inspect manually"
  fi
else
  check "index.html analytics strip" 0 "tags not found and CE marker missing — inspect manually"
fi

# ---------------------------------------------------------------------------
# 4. Optional hardening: pin the default Chatbox API origin to localhost
# ---------------------------------------------------------------------------
ORIGIN_FILE="src/shared/request/chatbox-api-origin.ts"
if [ "$HARD_ENDPOINTS" -eq 1 ]; then
  if [ -f "$ORIGIN_FILE" ] && grep -qF "[Chatbox CE]" "$ORIGIN_FILE"; then
    check "API origin hard-pinned" 1 "already pinned"
  elif [ -f "$ORIGIN_FILE" ] && grep -q "const DEFAULT_CHATBOX_API_ORIGIN = 'https://api.chatboxai.app'" "$ORIGIN_FILE"; then
    if [ "$VERIFY_ONLY" -eq 0 ]; then
      python3 - "$ORIGIN_FILE" <<'PYEOF' && ACTION_ORIGIN=1 || ACTION_ORIGIN=0
import sys
path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    text = f.read()
old = "const DEFAULT_CHATBOX_API_ORIGIN = 'https://api.chatboxai.app'"
new = ("// [Chatbox CE] official API origin pinned to an unroutable local address\n"
       "const DEFAULT_CHATBOX_API_ORIGIN = 'http://127.0.0.1:1'")
with open(path, 'w', encoding='utf-8', newline='') as f:
    f.write(text.replace(old, new, 1))
sys.exit(0)
PYEOF
      if [ "${ACTION_ORIGIN:-0}" -eq 1 ]; then
        ACTIONS+=("Pinned DEFAULT_CHATBOX_API_ORIGIN to http://127.0.0.1:1 in $ORIGIN_FILE")
        check "API origin hard-pinned" 1 "$ORIGIN_FILE"
      else
        check "API origin hard-pinned" 0 "patch failed"
      fi
    else
      check "API origin hard-pinned" 0 "run without --verify-only to pin"
    fi
  else
    check "API origin hard-pinned" 0 "$ORIGIN_FILE not found or pattern drifted"
  fi
else
  check "API origin (default mode)" 1 "left as upstream (run with --hard-endpoints to pin to 127.0.0.1:1)"
fi

# ---------------------------------------------------------------------------
# 5. Report telemetry npm dependencies (report-only, see notes)
# ---------------------------------------------------------------------------
DEPS_STILL=()
for dep in "@sentry/react" "@sentry/node" "@sentry/vite-plugin" "@sentry/webpack-plugin" "web-vitals" "@types/gtag.js" "@vibedrop/cli" "@vibedrop/sdk" "axios"; do
  if grep -q "\"$dep\"" package.json; then
    DEPS_STILL+=("$dep")
  fi
done
if [ "${#DEPS_STILL[@]}" -gt 0 ]; then
  check "Telemetry deps (report-only)" 1 "still declared (runtime imports kept for merge-friendliness): ${DEPS_STILL[*]}"
else
  check "Telemetry deps (report-only)" 1 "all pruned"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${#ACTIONS[@]}" -gt 0 ]; then
  echo "--- Actions taken this run ---"
  for action in "${ACTIONS[@]}"; do printf '  * %s\n' "$action"; done
  echo ""
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "SANITIZE RESULT: $FAILURES check(s) FAILED — inspect the FAIL lines above." >&2
  exit 1
fi
echo "SANITIZE RESULT: all checks passed. Community Edition is clean."
exit 0
