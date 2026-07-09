# ============================================================
# Focus Fitness OS - Local Backend + Cloudflare Tunnel Startup
# ============================================================
# Usage: Right-click -> Run with PowerShell
# Or:    powershell -ExecutionPolicy Bypass -File start-local-backend.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Focus Fitness OS - Backend Startup"    -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# --- Step 1: Check Node-RED ---
Write-Host "[1/4] Checking Node-RED..." -ForegroundColor Cyan
$nodeRed = Get-Command node-red -ErrorAction SilentlyContinue
if (-not $nodeRed) {
    Write-Host "  Installing Node-RED..." -ForegroundColor Yellow
    npm install -g node-red@4.0.2 2>&1 | Out-Null
}

# --- Step 2: Check sqlite3 binding ---
Write-Host "[2/4] Checking SQLite binding..." -ForegroundColor Cyan
$sqliteBinding = Join-Path $ScriptDir "node_modules\sqlite3\build\Release\node_sqlite3.node"
if (-not (Test-Path $sqliteBinding)) {
    Write-Host "  Rebuilding sqlite3..." -ForegroundColor Yellow
    npm rebuild sqlite3 2>&1 | Out-Null
}

# --- Step 3: Ensure data directory exists ---
Write-Host "[3/4] Preparing data directory..." -ForegroundColor Cyan
$dataDir = Join-Path $ScriptDir "data\db"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
}

# --- Step 4: Load environment from .env.local ---
Write-Host "[4/5] Loading environment from .env.local..." -ForegroundColor Cyan
$envFile = Join-Path $ScriptDir ".env.local"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                $name = $parts[0].Trim()
                $value = $parts[1].Trim()
                Set-Item -Path "env:$name" -Value $value
            }
        }
    }
    Write-Host "  Loaded .env.local" -ForegroundColor Green
} else {
    Write-Host "  WARNING: .env.local not found! Copy .env.example to .env.local and fill in values." -ForegroundColor Red
    Write-Host "  Node-RED will fail to start without required environment variables." -ForegroundColor Red
    exit 1
}
$env:TZ = 'Asia/Shanghai'
$env:FLOWS = 'flows.json'

# --- Step 5: Start Node-RED ---
Write-Host "[5/5] Starting Node-RED..." -ForegroundColor Cyan

$nodeRedProc = Start-Process -FilePath "node-red" -ArgumentList "-u .", "-s settings.js" -PassThru -NoNewWindow -RedirectStandardOutput "$ScriptDir\nodered.log" -RedirectStandardError "$ScriptDir\nodered.err"

# Wait for Node-RED to start
Write-Host "  Waiting for Node-RED to start..." -ForegroundColor Yellow
$startTimeout = 30
$startTime = Get-Date
$nodeRedReady = $false
while ((Get-Date) - $startTime -lt (New-TimeSpan -Seconds $startTimeout)) {
    Start-Sleep -Seconds 2
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:1880/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) {
            $nodeRedReady = $true
            break
        }
    } catch {}
}

if ($nodeRedReady) {
    Write-Host "  Node-RED is running at http://127.0.0.1:1880" -ForegroundColor Green
} else {
    Write-Host "  Node-RED failed to start within $startTimeout seconds" -ForegroundColor Red
    Write-Host "  Check nodered.log and nodered.err for details" -ForegroundColor Red
    exit 1
}

# --- Step 5: Start Cloudflare Quick Tunnel ---
Write-Host ""
Write-Host "Starting Cloudflare Quick Tunnel..." -ForegroundColor Cyan
$cloudflaredPath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
if (-not (Test-Path $cloudflaredPath)) {
    Write-Host "  cloudflared not found. Install with: winget install Cloudflare.cloudflared" -ForegroundColor Red
    Write-Host "  Backend is running locally at http://127.0.0.1:1880" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the backend." -ForegroundColor Yellow
    Start-Sleep -Seconds 999999
    exit 0
}

$tunnelProc = Start-Process -FilePath $cloudflaredPath -ArgumentList "tunnel", "--url", "http://localhost:1880" -PassThru -NoNewWindow -RedirectStandardOutput "$ScriptDir\tunnel.log" -RedirectStandardError "$ScriptDir\tunnel.err"

# Wait for tunnel URL
Write-Host "  Waiting for tunnel URL..." -ForegroundColor Yellow
$tunnelTimeout = 30
$tunnelStartTime = Get-Date
$tunnelUrl = $null
while ((Get-Date) - $tunnelStartTime -lt (New-TimeSpan -Seconds $tunnelTimeout)) {
    Start-Sleep -Seconds 2
    $tunnelLog = Get-Content "$ScriptDir\tunnel.err" -ErrorAction SilentlyContinue -Raw
    if ($tunnelLog -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
        $tunnelUrl = $matches[0]
        break
    }
}

if ($tunnelUrl) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Backend is LIVE!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Local:  http://127.0.0.1:1880" -ForegroundColor White
    Write-Host "  Public: $tunnelUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Login:  admin / [see .env.local for API password]" -ForegroundColor White
    Write-Host ""
    Write-Host "  NOTE: Quick Tunnel URL changes on restart." -ForegroundColor Yellow
    Write-Host "  For stable URL, set up a Named Tunnel:" -ForegroundColor Yellow
    Write-Host "  https://developers.cloudflare.com/cloudflare-one/connections/connect-apps" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press Ctrl+C to stop both services." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  Tunnel URL not found in logs. Check tunnel.err" -ForegroundColor Red
    Write-Host "  Backend is running locally at http://127.0.0.1:1880" -ForegroundColor Yellow
}

# Keep running until Ctrl+C
try {
    while ($true) {
        Start-Sleep -Seconds 60
        # Check if processes are still running
        if ($nodeRedProc.HasExited) {
            Write-Host "Node-RED process exited. Stopping..." -ForegroundColor Red
            break
        }
        if ($tunnelProc -and $tunnelProc.HasExited) {
            Write-Host "Cloudflare Tunnel process exited. Stopping..." -ForegroundColor Red
            break
        }
    }
} finally {
    # Cleanup
    if (-not $nodeRedProc.HasExited) { Stop-Process -Id $nodeRedProc.Id -Force -ErrorAction SilentlyContinue }
    if ($tunnelProc -and -not $tunnelProc.HasExited) { Stop-Process -Id $tunnelProc.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "Backend stopped." -ForegroundColor Yellow
}
