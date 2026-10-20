# Windows launcher.   powershell -ExecutionPolicy Bypass -File start.ps1 [up|down|logs|reset]
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$cmd = if ($args.Count) { $args[0] } else { 'up' }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host 'Docker is not installed. Install Docker Desktop, start it, then run this again.'; exit 1 }
docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'Docker is installed but not running. Start Docker Desktop and try again.'; exit 1 }

switch ($cmd) {
  'down'  { docker compose down; exit 0 }
  'logs'  { docker compose logs -f --tail=100; exit 0 }
  'reset' { if ((Read-Host 'This deletes saved contact messages. Continue? [y/N]') -eq 'y') { docker compose down -v }; exit 0 }
  'up'    { }
  default { Write-Host 'Usage: start.ps1 [up|down|logs|reset]'; exit 1 }
}

function New-Secret { $b = New-Object byte[] 24; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); ($b | ForEach-Object { $_.ToString('x2') }) -join '' }
function Get-EnvValue($k) { $m = Select-String -Path .env -Pattern "^$k=(.*)$" | Select-Object -First 1; if ($m) { $m.Matches[0].Groups[1].Value } else { '' } }
function Set-EnvValue($k, $v) { $lines = Get-Content .env; if ($lines -match "^$k=") { $lines = $lines -replace "^$k=.*$", "$k=$v" } else { $lines += "$k=$v" }; Set-Content -Path .env -Value $lines -Encoding ascii }

if (-not (Test-Path .env)) {
  Write-Host 'Creating .env with fresh random passwords...'
  (Get-Content .env.example) -replace '^MONGO_PASSWORD=.*$', "MONGO_PASSWORD=$(New-Secret)" -replace '^REDIS_PASSWORD=.*$', "REDIS_PASSWORD=$(New-Secret)" | Set-Content -Path .env -Encoding ascii
}

if (-not (Get-EnvValue 'ANTHROPIC_API_KEY')) {
  $key = $env:ANTHROPIC_API_KEY
  if (-not $key) {
    $sec = Read-Host 'Anthropic API key for the AI chat (press Enter to skip)' -AsSecureString
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  }
  if ($key) { Set-EnvValue 'ANTHROPIC_API_KEY' $key }
}

Write-Host 'Building and starting. The first run takes a few minutes...'
docker compose up --build -d
if ($LASTEXITCODE -ne 0) { Write-Host 'Docker could not start the stack. See the messages above.'; exit 1 }

Write-Host -NoNewline 'Waiting for the site'
for ($i = 0; $i -lt 60; $i++) {
  try {
    Invoke-WebRequest -UseBasicParsing http://localhost:8080/api/health | Out-Null
    Write-Host ''; Write-Host 'Your portfolio is running at http://localhost:8080'
    if (-not (Get-EnvValue 'ANTHROPIC_API_KEY')) { Write-Host 'AI chat: using built-in answers. Add ANTHROPIC_API_KEY to .env and run this script again for live AI answers.' } else { Write-Host 'AI chat: live AI answers are on.' }
    Write-Host 'Stop: start.ps1 down   |   Logs: start.ps1 logs'
    exit 0
  } catch { Write-Host -NoNewline '.'; Start-Sleep -Seconds 2 }
}
Write-Host ''; Write-Host 'The site did not become ready in time. See what went wrong with: start.ps1 logs'; exit 1
