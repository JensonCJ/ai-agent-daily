# Publish the daily pages to GitHub Pages.  ASCII-only source.
#   pwsh -NoProfile -File deploy-pages.ps1 [-Message "day04"]
# Reads pageUrlBase from ../plan.json to derive the git remote, so no extra config.
param([string]$Message = 'update daily pages')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot      # the 每日一章 folder
$site = $PSScriptRoot

$planPath = Join-Path $root 'plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
$base = ''
if ($plan.pageUrlBase) { $base = ([string]$plan.pageUrlBase).Trim() }
if ($base.Length -eq 0) { Write-Host 'pageUrlBase is empty -- nothing to deploy'; exit 1 }

# 1) copy only the publishable pages (never plan.json / scripts / logs)
$pages = Get-ChildItem $root -Filter '*.html' -File | Where-Object { $_.Name -eq 'index.html' -or $_.Name -match '^day\d{2}\.html$' }
foreach ($p in $pages) { Copy-Item -LiteralPath $p.FullName -Destination (Join-Path $site $p.Name) -Force }
Write-Host ('copied ' + $pages.Count + ' pages')

# 2) remote from pageUrlBase: https://USER.github.io/REPO/ -> https://github.com/USER/REPO.git
$uri = [uri]$base
$user = $uri.Host.Split('.')[0]
$repo = $uri.AbsolutePath.Trim('/').Split('/')[0]
$remote = 'https://github.com/' + $user + '/' + $repo + '.git'

Push-Location $site
try {
  if (-not (Test-Path (Join-Path $site '.git'))) {
    git init | Out-Null
    git branch -M main
  }
  $existing = @(git remote)
  if ($existing -contains 'origin') { git remote set-url origin $remote } else { git remote add origin $remote }
  Write-Host ('remote: ' + $remote)

  git add -A
  $staged = @(git diff --cached --name-only)
  if ($staged.Count -eq 0) { Write-Host 'nothing to commit'; exit 0 }
  git commit -m $Message | Out-Null
  Write-Host ('committed ' + $staged.Count + ' files')

  # 3) push: try direct first, then through the local proxy (this machine's
  #    github.com route is a transparent proxy fake-IP that often drops).
  $ok = $false
  & git push -u origin main 2>&1 | ForEach-Object { Write-Host ('  ' + $_) }
  if ($LASTEXITCODE -eq 0) { $ok = $true }

  if (-not $ok) {
    Write-Host 'direct push failed -- retrying through http://127.0.0.1:7897'
    git config --local http.proxy http://127.0.0.1:7897
    & git push -u origin main 2>&1 | ForEach-Object { Write-Host ('  ' + $_) }
    if ($LASTEXITCODE -eq 0) { $ok = $true }
  }

  if ($ok) { Write-Host ('deployed -> ' + $base) } else { Write-Host 'PUSH FAILED'; exit 1 }
} finally {
  Pop-Location
}
