# Publish the daily pages to GitHub Pages.  ASCII-only source.
#   pwsh -NoProfile -File deploy-pages.ps1 [-Message "update"]
# Reads pageUrlBase from ../plan.json to derive the git remote, so no extra config.
param([string]$Message = 'update daily pages')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot      # the 每日一章 folder
$site = $PSScriptRoot

$planPath = Join-Path $root 'plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
$base = ''
if ($plan.pageUrlBase) { $base = ([string]$plan.pageUrlBase).Trim() }

# 1) copy only the publishable pages (never plan.json / scripts / logs)
$pages = Get-ChildItem $root -Filter '*.html' -File | Where-Object { $_.Name -eq 'index.html' -or $_.Name -match '^day\d{2}\.html$' }
foreach ($p in $pages) { Copy-Item -LiteralPath $p.FullName -Destination (Join-Path $site $p.Name) -Force }
Write-Host ('copied ' + $pages.Count + ' pages')

# 2) remote from pageUrlBase: https://USER.github.io/REPO/ -> https://github.com/USER/REPO.git
if ($base.Length -gt 0) {
  $uri = [uri]$base
  $user = $uri.Host.Split('.')[0]
  $repo = $uri.AbsolutePath.Trim('/').Split('/')[0]
  $remote = 'https://github.com/' + $user + '/' + $repo + '.git'
  Push-Location $site
  if (-not (Test-Path (Join-Path $site '.git'))) { git init | Out-Null; git branch -M main }
  $existing = @(git remote)
  if ($existing -contains 'origin') { git remote set-url origin $remote } else { git remote add origin $remote }
  Write-Host ('remote: ' + $remote)
} else {
  Write-Host 'pageUrlBase is empty -- copied files only, no remote configured'
  exit 0
}

# 3) commit + push
git add -A
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) { Write-Host 'nothing to commit'; Pop-Location; exit 0 }
git commit -m $Message | Out-Null
git push -u origin main
Pop-Location
Write-Host 'pushed'
