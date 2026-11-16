#Requires -Version 5.1
<#
.SYNOPSIS
    [Chatbox CE] Sanitizer - idempotent privacy/telemetry sanitization for the
    Chatbox Community Edition (GPLv3 fork of chatboxai/chatbox).

.DESCRIPTION
    Run this script after merging upstream updates to re-verify (and, where
    possible, re-apply) the Community Edition sanitization. It:

      1. Verifies every `[Chatbox CE]` gate marker is still present in the
         patched hot-spots (telemetry init chain, GA IPC bridge, remote
         content, update feed, default settings).
      2. Removes upstream files/directories that must not exist in the CE
         (anti-piracy guard, team-sharing docs) - idempotent.
      3. Strips the Google Analytics / Plausible tags from src/renderer/index.html
         (re-applies automatically if an upstream merge restores them).
      4. Optional hardening with -HardEndpoints: points the default Chatbox API
         origin at an unroutable local address so no official endpoint can be
         reached even if a code path regresses.
      5. Reports (does NOT remove) the npm telemetry dependencies, because the
         runtime imports are intentionally kept for upstream-merge friendliness.

    Convention: every CE code edit is marked with the literal marker
    `[Chatbox CE]`. The verifier keys off that marker.

.PARAMETER HardEndpoints
    Additionally neutralize `src/shared/request/chatbox-api-origin.ts` default
    origin (replaced with http://127.0.0.1:1, unroutable).

.PARAMETER VerifyOnly
    Only run the verification pass; apply nothing, delete nothing.

.EXAMPLE
    pwsh ./build-scripts/sanitize.ps1                # verify + apply
    pwsh ./build-scripts/sanitize.ps1 -VerifyOnly    # verify only
    pwsh ./build-scripts/sanitize.ps1 -HardEndpoints # also pin the API origin to localhost
#>

[CmdletBinding()]
param(
    [switch]$HardEndpoints,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$script:Checks = New-Object System.Collections.Generic.List[object]
$script:Actions = New-Object System.Collections.Generic.List[string]

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail = '') {
    $script:Checks.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
}

function Test-MarkerInFile([string]$RelPath, [string]$Marker) {
    $path = Join-Path $RepoRoot $RelPath
    if (-not (Test-Path $path)) { return $false }
    # -SimpleMatch means the pattern is a literal string; do NOT regex-escape it
    # (Regex.Escape would turn spaces into '\ ' and break literal matching).
    return (Select-String -LiteralPath $path -Pattern $Marker -SimpleMatch -Quiet)
}

function Get-FileText([string]$RelPath) {
    $path = Join-Path $RepoRoot $RelPath
    if (-not (Test-Path $path)) { return $null }
    return [System.IO.File]::ReadAllText($path)
}

function Set-FileText([string]$RelPath, [string]$Content) {
    $path = Join-Path $RepoRoot $RelPath
    [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host ""
Write-Host "=== [Chatbox CE] sanitize run - repo: $RepoRoot ===" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Verify the code gates (marker-based)
# ---------------------------------------------------------------------------
$gateChecks = @(
    @{ Name = 'CE master switch module exists';        File = 'src/shared/ce-edition.ts';                    Marker = 'CE_EDITION' },
    @{ Name = 'Renderer telemetry init chain gated';   File = 'src/renderer/app/bootstrapRenderer.ts';       Marker = 'if (!CE_DISABLE_TELEMETRY)' },
    @{ Name = 'Renderer API-origin probing gated';     File = 'src/renderer/app/bootstrapRenderer.ts';       Marker = 'if (!CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Main-process Sentry gated';             File = 'src/main/adapters/sentry.ts';                 Marker = 'if (CE_DISABLE_TELEMETRY)' },
    @{ Name = 'GA Measurement-Protocol IPC gated';     File = 'src/main/main.ts';                            Marker = 'if (CE_DISABLE_TELEMETRY)' },
    @{ Name = 'Renderer analytics wrapper gated';      File = 'src/renderer/packages/event.ts';              Marker = 'if (CE_DISABLE_TELEMETRY)' },
    @{ Name = 'Web gtag undefined guard';              File = 'src/renderer/platform/web_platform.ts';       Marker = "typeof window.gtag !== 'function'" },
    @{ Name = 'Official update check (web) gated';     File = 'src/renderer/hooks/useVersion.ts';            Marker = 'if (CE_DISABLE_OFFICIAL_UPDATER)' },
    @{ Name = 'Official updater (main) gated';         File = 'src/main/app-updater.ts';                     Marker = 'if (CE_DISABLE_OFFICIAL_UPDATER)' },
    @{ Name = 'Remote config sync static in CE';       File = 'src/renderer/routes/__root.tsx';              Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Remote dialog / notifications gated';   File = 'src/renderer/routes/__root.tsx';              Marker = 'RemoteDialogWindow' },
    @{ Name = 'Builtin-skill backend sync gated';      File = 'src/main/skills/builtin-sync.ts';             Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Telemetry consent defaults to false';   File = 'packages/chatbox-core/src/domain/settings/settings-defaults.ts'; Marker = 'allowReportingAndTracking: false' },
    @{ Name = 'Document parser defaults to local';     File = 'packages/chatbox-core/src/domain/settings/settings-defaults.ts'; Marker = "type: 'local'" },
    @{ Name = 'Vibedrop not enabled by default';       File = 'src/shared/types/skills.ts';                  Marker = 'Vibedrop is a third-party SaaS' },
    @{ Name = 'Error Reporting switch removed (UI)';   File = 'src/renderer/routes/settings/advanced.tsx';   Marker = 'Error Reporting switch is removed' },
    @{ Name = 'Account > Chatbox AI nav removed';      File = 'src/renderer/components/settings/settingsNav.tsx'; Marker = 'Account > Chatbox AI' },
    @{ Name = 'Chatbox AI settings card removed';      File = 'src/renderer/routes/settings/route.tsx';      Marker = 'Chatbox AI account card removed' },
    @{ Name = 'Free-license claim banner removed';     File = 'src/renderer/routes/settings/web-search.tsx'; Marker = 'free-license claim banner removed' },
    @{ Name = 'Cloud parser option filtered (UI)';     File = 'src/renderer/components/settings/DocumentParserSettings.tsx'; Marker = 'Chatbox AI cloud parser is not offered' },
    @{ Name = 'Chatbox AI Search filtered (slots)';    File = 'src/renderer/routes/settings/default-models.tsx'; Marker = 'Chatbox AI Search) provider is not offered' },
    @{ Name = 'Remote model catalog gated';            File = 'src/renderer/hooks/useChatboxAIModels.ts';    Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Free-trial banner removed (errors)';    File = 'src/renderer/components/chat/GenericMessageError.tsx'; Marker = 'Chatbox AI free trial banner removed' },
    @{ Name = 'KB cloud-parsing suggestion removed';   File = 'src/renderer/components/knowledge-base/KnowledgeBaseDocuments.tsx'; Marker = 'never suggest Chatbox AI cloud parsing' },
    @{ Name = 'Welcome purchase funnel suppressed';    File = 'src/renderer/utils/homeWelcomeCard.ts';       Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Official check-update link removed';    File = 'src/renderer/components/DbSchemaGuardDialog.tsx'; Marker = 'official check-update redirect link removed' },
    @{ Name = 'Menu website link replaced';            File = 'src/main/menu.ts';                            Marker = 'official website replaced' },
    @{ Name = 'About page links neutralized';          File = 'src/renderer/routes/about.tsx';               Marker = 'official privacy/terms links removed' },
    @{ Name = 'About updater links gated';             File = 'src/renderer/routes/about.tsx';               Marker = 'CE_DISABLE_OFFICIAL_UPDATER' },
    @{ Name = 'Chatbox AI hidden from provider list';  File = 'src/renderer/components/settings/provider/ProviderList.tsx'; Marker = 'is never listed' },
    @{ Name = 'Chatbox AI Search filtered (settings)'; File = 'src/renderer/routes/settings/web-search.tsx'; Marker = 'filtered out of the provider list' },
    @{ Name = 'Builtin subscription MCP removed';      File = 'packages/chatbox-core/src/mcp/builtin.ts';    Marker = 'metered by Chatbox AI license keys' },
    @{ Name = 'Settings landing no longer login page'; File = 'src/renderer/routes/settings/index.tsx';      Marker = 'no longer redirects to the Chatbox AI login' },
    @{ Name = 'License banner removed (chat errors)';  File = 'src/renderer/components/chat/GenericMessageError.tsx'; Marker = 'license banner removed' },
    @{ Name = 'KB login banner removed';               File = 'src/renderer/components/knowledge-base/KnowledgeBase.tsx'; Marker = 'knowledge-base login banner removed' },
    @{ Name = 'InputBox search panel filtered';        File = 'src/renderer/components/InputBox/AgentModePanel.tsx'; Marker = 'not offered in the panel' },
    @{ Name = 'MCP builtin section removed (page)';    File = 'src/renderer/routes/settings/mcp.tsx';        Marker = 'Builtin subscription MCP servers section removed' },
    @{ Name = 'Preset demo conversations not seeded';  File = 'src/renderer/setup/init_data.ts';             Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'KB form parser option filtered';        File = 'src/renderer/components/knowledge-base/KnowledgeBaseForm.tsx'; Marker = 'cloud parser / provider-mode options removed' },
    @{ Name = 'KB remote model config gated';          File = 'src/renderer/components/knowledge-base/KnowledgeBase.tsx'; Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Onboarding guide auto-navigate gated';  File = 'src/renderer/routes/__root.tsx';              Marker = 'CE_DISABLE_REMOTE_CONTENT || shouldSkipOnboardingGuide' },
    @{ Name = 'Guide chat API hard-stopped';           File = 'src/renderer/routes/guide/-utils/guideApi.ts'; Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Sidebar Help button repointed';         File = 'src/renderer/Sidebar.tsx';                    Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Parser slot filtered (default-models)'; File = 'src/renderer/routes/settings/default-models.tsx'; Marker = 'cloud parser is not offered in slot selectors' },
    @{ Name = 'Web-search issue neutralized (CE)';     File = 'src/renderer/packages/web-search/configuration-issue.ts'; Marker = 'if (CE_DISABLE_REMOTE_CONTENT)' },
    @{ Name = 'Search banner neutral copy';            File = 'src/renderer/components/InputBox/WebSearchUnavailableBanner.tsx'; Marker = 'provider-unavailable' },
    @{ Name = 'Tool sign-in card removed';             File = 'src/renderer/components/message-parts/ToolUnavailableCard.tsx'; Marker = 'sign-in card is never shown' },
    @{ Name = 'Attachment parser brand hidden';        File = 'src/renderer/components/InputBox/Attachments.tsx'; Marker = 'legacy cloud-parsed attachments show no parser brand' },
    @{ Name = 'Parser descriptions neutralized';       File = 'src/renderer/components/settings/DocumentParserSettings.tsx'; Marker = 'descriptions no longer steer users toward Chatbox AI' },
    @{ Name = 'KB subscription info card removed';     File = 'src/renderer/components/knowledge-base/KnowledgeBaseForm.tsx'; Marker = 'Chatbox AI subscription info card is not shown' }
)

foreach ($check in $gateChecks) {
    $passed = Test-MarkerInFile -RelPath $check.File -Marker $check.Marker
    Add-Check -Name $check.Name -Passed $passed -Detail $check.File
}

# ---------------------------------------------------------------------------
# 2. Delete upstream leaf files / directories (idempotent)
# ---------------------------------------------------------------------------
$removals = @(
    @{ Path = 'src/renderer/setup/protect.ts'; Reason = 'Anti-piracy domain guard (dormant upstream code, decrypts chatboxai.app constants)' },
    @{ Path = 'team-sharing';                  Reason = 'Team-sharing docker docs (removed per CE policy; self-hosted proxy, no code references)' }
)

foreach ($removal in $removals) {
    $full = Join-Path $RepoRoot $removal.Path
    if (Test-Path $full) {
        if ($VerifyOnly) {
            Add-Check -Name "Should be absent: $($removal.Path)" -Passed $false -Detail 'present; run without -VerifyOnly to remove'
        } else {
            $resolved = (Resolve-Path $full).Path
            if (-not $resolved.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to delete outside repo: $resolved"
            }
            Remove-Item -Recurse -Force $resolved
            $script:Actions.Add("Deleted $($removal.Path) - $($removal.Reason)")
            Add-Check -Name "Absent: $($removal.Path)" -Passed $true -Detail 'removed by this run'
        }
    } else {
        Add-Check -Name "Absent: $($removal.Path)" -Passed $true -Detail 'already removed'
    }
}

# ---------------------------------------------------------------------------
# 3. Re-apply the index.html analytics strip (idempotent regex patch)
# ---------------------------------------------------------------------------
$indexPath = 'src/renderer/index.html'
$html = Get-FileText $indexPath
if ($null -eq $html) {
    Add-Check -Name 'index.html exists' -Passed $false -Detail $indexPath
} elseif ($html.Contains('[Chatbox CE]')) {
    Add-Check -Name 'index.html analytics strip present' -Passed $true -Detail 'CE marker found'
} else {
    # Upstream merge restored the tags - strip the whole GA + Plausible block again.
    $pattern = '(?s)\s*<!-- Google tag \(gtag\.js\) -->.*?</script>\s*<script>\s*window\.plausible =.*?</script>\s*<script>\s*window\.dataLayer = window\.dataLayer \|\| \[\];.*?gtag\("js", new Date\(\)\);\s*// gtag\(.config., .G-B365F44W6E.\);\s*</script>'
    $replacement = @"

    <!-- [Chatbox CE] Google Analytics (gtag.js) and Plausible script tags removed.
         window.gtag / window.plausible stay undefined, so every tracking wrapper
         in the renderer takes its no-op path. -->
"@
    $patched = [regex]::Replace($html, $pattern, $replacement, 1)
    if ($patched -ne $html) {
        if (-not $VerifyOnly) {
            Set-FileText -RelPath $indexPath -Content $patched
            $script:Actions.Add("Stripped GA/Plausible tags from $indexPath (re-applied after upstream merge)")
        }
        Add-Check -Name 'index.html analytics strip' -Passed (-not $VerifyOnly) -Detail 'was restored upstream; re-stripped'
    } else {
        Add-Check -Name 'index.html analytics strip' -Passed $false -Detail 'tags not found and marker missing - inspect manually'
    }
}

# ---------------------------------------------------------------------------
# 4. Optional hardening: pin the default Chatbox API origin to localhost
# ---------------------------------------------------------------------------
$originFile = 'src/shared/request/chatbox-api-origin.ts'
$originText = Get-FileText $originFile
if ($HardEndpoints) {
    $pinned = "http://127.0.0.1:1" # unroutable loopback port - every official API call fails fast
    if ($originText -and $originText.Contains('https://api.chatboxai.app') -and -not $originText.Contains('[Chatbox CE]')) {
        if (-not $VerifyOnly) {
            $patched = $originText.Replace(
                "const DEFAULT_CHATBOX_API_ORIGIN = 'https://api.chatboxai.app'",
                "// [Chatbox CE] official API origin pinned to an unroutable local address`nconst DEFAULT_CHATBOX_API_ORIGIN = '$pinned'"
            )
            Set-FileText -RelPath $originFile -Content $patched
            $script:Actions.Add("Pinned DEFAULT_CHATBOX_API_ORIGIN to $pinned in $originFile")
        }
        Add-Check -Name 'API origin hard-pinned' -Passed (-not $VerifyOnly) -Detail $originFile
    } elseif ($originText -and $originText.Contains('[Chatbox CE]')) {
        Add-Check -Name 'API origin hard-pinned' -Passed $true -Detail 'already pinned'
    } else {
        Add-Check -Name 'API origin hard-pinned' -Passed $false -Detail "$originFile not found or pattern drifted"
    }
} else {
    $pinnedAlready = $originText -and $originText.Contains('[Chatbox CE]')
    Add-Check -Name 'API origin (default mode)' -Passed $true -Detail $(if ($pinnedAlready) { 'pinned' } else { 'left as upstream (run with -HardEndpoints to pin to 127.0.0.1:1)' })
}

# ---------------------------------------------------------------------------
# 5. Report telemetry npm dependencies (report-only, see notes)
# ---------------------------------------------------------------------------
$telemetryDeps = @('@sentry/react', '@sentry/node', '@sentry/vite-plugin', '@sentry/webpack-plugin', 'web-vitals', '@types/gtag.js', '@vibedrop/cli', '@vibedrop/sdk', 'axios')
$pkgJson = Get-Content (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json
$declared = @()
foreach ($dep in $telemetryDeps) {
    if ($pkgJson.devDependencies.PSObject.Properties.Name -contains $dep -or
        $pkgJson.dependencies.PSObject.Properties.Name -contains $dep) {
        $declared += $dep
    }
}
Add-Check -Name 'Telemetry deps (report-only)' -Passed $true -Detail $(if ($declared.Count) { "still declared (runtime imports kept for merge-friendliness): $($declared -join ', ')" } else { 'all pruned' })

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- Verification results ---" -ForegroundColor Cyan
$failed = 0
foreach ($check in $script:Checks) {
    $status = if ($check.Passed) { 'PASS' } else { 'FAIL'; }
    if (-not $check.Passed) { $failed++ }
    $color = if ($check.Passed) { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1}" -f $status, $check.Name) -ForegroundColor $color
    if ($check.Detail) { Write-Host ("         {0}" -f $check.Detail) -ForegroundColor DarkGray }
}

if ($script:Actions.Count -gt 0) {
    Write-Host ""
    Write-Host "--- Actions taken this run ---" -ForegroundColor Cyan
    foreach ($action in $script:Actions) { Write-Host ("  * {0}" -f $action) -ForegroundColor Yellow }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host "SANITIZE RESULT: $failed check(s) FAILED - inspect the FAIL lines above." -ForegroundColor Red
    exit 1
}
Write-Host "SANITIZE RESULT: all checks passed. Community Edition is clean." -ForegroundColor Green
exit 0
