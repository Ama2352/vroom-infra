#Requires -Version 5.1
<#
.SYNOPSIS
  Copies sealed secrets produced by seal-secrets.yml into vroom-gitops,
  then commits and pushes to GitHub so ArgoCD can sync them.

.DESCRIPTION
  Run this once after every `vagrant up` from the vroom-infra directory:
    cd vroom-infra
    .\scripts\apply-sealed-secrets.ps1

  Prerequisites:
    - vagrant up has completed (argocd.yml ran and produced .secrets/sealed/)
    - vroom-gitops is cloned at the sibling path ../vroom-gitops
    - Git is on your PATH
    - Either GITHUB_GITOPS_TOKEN env var is set, or you will be prompted
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$infraRoot  = $PSScriptRoot | Split-Path -Parent   # vroom-infra/
$sealedRoot = Join-Path $infraRoot ".secrets\sealed"
$gitopsRoot = Join-Path $infraRoot "..\vroom-gitops"

# ── Validate preconditions ─────────────────────────────────────────────────

if (-not (Test-Path $sealedRoot)) {
    Write-Error "Sealed secrets not found at $sealedRoot. Run 'vagrant up' first."
}

if (-not (Test-Path $gitopsRoot)) {
    Write-Error "vroom-gitops not found at $gitopsRoot. Clone it alongside vroom-infra."
}

# ── Mapping: sealed path → vroom-gitops destination ──────────────────────

$mappings = @(
    @{ Src = "apps\user\overlays\dev\secrets\user-db-secrets.yaml";              Dst = "apps\user\overlays\dev\secrets\user-db-secrets.yaml" }
    @{ Src = "apps\ride\overlays\dev\secrets\ride-db-secrets.yaml";              Dst = "apps\ride\overlays\dev\secrets\ride-db-secrets.yaml" }
    @{ Src = "apps\notification\overlays\dev\secrets\notification-db-secrets.yaml"; Dst = "apps\notification\overlays\dev\secrets\notification-db-secrets.yaml" }
    @{ Src = "apps\user\overlays\staging\secrets\user-db-secrets.yaml";          Dst = "apps\user\overlays\staging\secrets\user-db-secrets.yaml" }
    @{ Src = "apps\ride\overlays\staging\secrets\ride-db-secrets.yaml";          Dst = "apps\ride\overlays\staging\secrets\ride-db-secrets.yaml" }
    @{ Src = "apps\notification\overlays\staging\secrets\notification-db-secrets.yaml"; Dst = "apps\notification\overlays\staging\secrets\notification-db-secrets.yaml" }
    @{ Src = "apps\user\overlays\prod\secrets\user-db-secrets.yaml";             Dst = "apps\user\overlays\prod\secrets\user-db-secrets.yaml" }
    @{ Src = "apps\ride\overlays\prod\secrets\ride-db-secrets.yaml";             Dst = "apps\ride\overlays\prod\secrets\ride-db-secrets.yaml" }
    @{ Src = "apps\notification\overlays\prod\secrets\notification-db-secrets.yaml"; Dst = "apps\notification\overlays\prod\secrets\notification-db-secrets.yaml" }
    @{ Src = "apps\ai-reporter\secrets\ai-reporter-secret.yaml";                 Dst = "apps\ai-reporter\secrets\ai-reporter-secret.yaml" }
    @{ Src = "infrastructure\postgres\secrets\user-db-secrets.yaml";             Dst = "infrastructure\postgres\secrets\user-db-secrets.yaml" }
    @{ Src = "infrastructure\postgres\secrets\ride-db-secrets.yaml";             Dst = "infrastructure\postgres\secrets\ride-db-secrets.yaml" }
    @{ Src = "infrastructure\postgres\secrets\notification-db-secrets.yaml";     Dst = "infrastructure\postgres\secrets\notification-db-secrets.yaml" }
    @{ Src = "infrastructure\observability\metrics\alertmanager-slack-secret.yaml"; Dst = "infrastructure\observability\metrics\alertmanager-slack-secret.yaml" }
    @{ Src = "infrastructure\kargo\secrets\kargo-admin-password.yaml";           Dst = "infrastructure\kargo\secrets\kargo-admin-password.yaml" }
    @{ Src = "kargo\secrets\ai-reporter-secret.yaml";                            Dst = "kargo\secrets\ai-reporter-secret.yaml" }
)

# ── Copy files ────────────────────────────────────────────────────────────

Write-Host "`nCopying sealed secrets to vroom-gitops..." -ForegroundColor Cyan

foreach ($m in $mappings) {
    $src = Join-Path $sealedRoot $m.Src
    $dst = Join-Path $gitopsRoot $m.Dst

    if (-not (Test-Path $src)) {
        Write-Warning "  SKIP (not found): $($m.Src)"
        continue
    }

    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    }

    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  OK  $($m.Dst)" -ForegroundColor Green
}

# ── Commit and push ───────────────────────────────────────────────────────

Write-Host "`nCommitting sealed secrets to vroom-gitops..." -ForegroundColor Cyan

Push-Location $gitopsRoot
try {
    git add apps/user/overlays/ `
             apps/ride/overlays/ `
             apps/notification/overlays/ `
             apps/ai-reporter/secrets/ `
             infrastructure/postgres/secrets/ `
             "infrastructure/observability/metrics/alertmanager-slack-secret.yaml" `
             infrastructure/kargo/secrets/ `
             kargo/secrets/

    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nothing to commit — sealed secrets are already up to date." -ForegroundColor Yellow
        return
    }

    git commit -m "chore: re-seal secrets after cluster recreation"

    # Push using GITHUB_GITOPS_TOKEN if available, otherwise rely on stored credentials
    $token = $env:GITHUB_GITOPS_TOKEN
    if ($token) {
        $remote = git remote get-url origin
        # Inject token into HTTPS remote URL
        $authedRemote = $remote -replace "https://", "https://$token@"
        git push $authedRemote HEAD:main
    } else {
        Write-Host "GITHUB_GITOPS_TOKEN not set — attempting push with stored credentials." -ForegroundColor Yellow
        git push origin HEAD:main
    }

    Write-Host "`nDone. ArgoCD will auto-sync the sealed secrets within ~3 minutes." -ForegroundColor Green
}
finally {
    Pop-Location
}
