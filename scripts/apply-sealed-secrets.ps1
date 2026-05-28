#Requires -Version 5.1
<#
.SYNOPSIS
  Fallback script: copies sealed secrets from .secrets/sealed/ to vroom-gitops/secrets/
  and pushes to GitHub. Use this if the Ansible git push inside the VM failed.

.DESCRIPTION
  The primary sealing workflow is fully automated via ansible/seal-secrets.yml.
  Run this script only if you need to re-sync sealed files manually:
    cd vroom-infra
    .\scripts\apply-sealed-secrets.ps1

  Prerequisites:
    - seal-secrets.yml (Ansible) has run and produced files in .secrets/sealed/
    - vroom-gitops is cloned at the sibling path ../vroom-gitops
    - Git is on your PATH
    - GITHUB_GITOPS_TOKEN env var is set
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$infraRoot  = $PSScriptRoot | Split-Path -Parent   # vroom-infra/
$sealedRoot = Join-Path $infraRoot ".secrets\sealed"
$gitopsRoot = Join-Path $infraRoot "..\vroom-gitops"

if (-not (Test-Path $sealedRoot)) {
    Write-Error "Sealed secrets not found at $sealedRoot. Run vagrant provision --provision-with seal-secrets.yml first."
}
if (-not (Test-Path $gitopsRoot)) {
    Write-Error "vroom-gitops not found at $gitopsRoot. Clone it alongside vroom-infra."
}

# ── Mapping: namespace/name pairs to copy ────────────────────────────────
# Structure mirrors: .secrets/sealed/<namespace>/<name>.yaml → secrets/<namespace>/<name>.yaml

$namespaces = @("vroom-dev", "vroom-staging", "vroom-prod", "platform", "monitoring", "vroom-kargo", "vroom")

Write-Host "`nCopying sealed secrets to vroom-gitops/secrets/..." -ForegroundColor Cyan

$copied = 0
foreach ($ns in $namespaces) {
    $srcDir = Join-Path $sealedRoot $ns
    $dstDir = Join-Path $gitopsRoot "secrets\$ns"

    if (-not (Test-Path $srcDir)) {
        Write-Host "  SKIP (dir not found): $ns/" -ForegroundColor DarkYellow
        continue
    }

    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    }

    foreach ($file in (Get-ChildItem $srcDir -Filter "*.yaml")) {
        $dst = Join-Path $dstDir $file.Name
        Copy-Item -Path $file.FullName -Destination $dst -Force
        Write-Host "  OK   $ns/$($file.Name)" -ForegroundColor Green
        $copied++
    }
}

if ($copied -eq 0) {
    Write-Host "`nNo sealed secrets found — nothing to commit." -ForegroundColor Yellow
    exit 0
}

# ── Enable placeholders in kustomization if sealed files now exist ────────
$kustomizationPath = Join-Path $gitopsRoot "secrets\kustomization.yaml"
$kustomContent = Get-Content $kustomizationPath -Raw
$placeholders = @("vroom/ghcr-creds.yaml", "monitoring/n8n-sealed-secret.yaml", "monitoring/kubectl-executor-secret.yaml")
foreach ($p in $placeholders) {
    $sealedPath = Join-Path $sealedRoot ($p -replace "/", "\")
    if (Test-Path $sealedPath) {
        $kustomContent = $kustomContent -replace "  # - $([regex]::Escape($p))", "  - $p"
    }
}
Set-Content -Path $kustomizationPath -Value $kustomContent -NoNewline

# ── Commit and push ───────────────────────────────────────────────────────
Write-Host "`nCommitting to vroom-gitops..." -ForegroundColor Cyan

Push-Location $gitopsRoot
try {
    git add secrets/

    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nothing to commit — sealed secrets are already up to date." -ForegroundColor Yellow
        return
    }

    git commit -m "chore: re-seal secrets after cluster recreation"

    $token = $env:GITHUB_GITOPS_TOKEN
    if ($token) {
        $remote = git remote get-url origin
        $authedRemote = $remote -replace "https://", "https://$token@"
        git push $authedRemote HEAD:main
    } else {
        Write-Host "GITHUB_GITOPS_TOKEN not set — attempting push with stored credentials." -ForegroundColor Yellow
        git push origin HEAD:main
    }

    Write-Host "`nDone. ArgoCD will auto-sync secrets within ~3 minutes." -ForegroundColor Green
}
finally {
    Pop-Location
}
