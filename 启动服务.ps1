# zcode-proxy 后台启动脚本
# 静默启动服务，无窗口，进程常驻

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = $PSScriptRoot
$Proj = Join-Path $Root '_src\zcode-api-master'
$Bun  = Join-Path $Root '.tools\bun-windows-x64\bun.exe'
$LogDir = Join-Path $Root 'logs'
$OutLog = Join-Path $LogDir 'proxy.log'
$ErrLog = Join-Path $LogDir 'proxy.err.log'

function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Fail($m)  { Write-Host $m -ForegroundColor Red }

Write-Host ''
Info '  =============================================='
Info '   ZCode Proxy  -  后台启动'
Info '  =============================================='
Write-Host ''

# --- 环境检查 ---
if (-not (Test-Path $Bun))  { Fail "  [X] 找不到 bun: $Bun"; Read-Host '  按回车退出'; exit 1 }
if (-not (Test-Path $Proj)) { Fail "  [X] 找不到项目: $Proj"; Read-Host '  按回车退出'; exit 1 }

# --- 是否已在运行 ---
$existing = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    $p = Get-Process -Id $existing[0].OwningProcess -ErrorAction SilentlyContinue
    Warn "  [!] 服务已在运行 (PID $($p.Id))"
    Info '      地址: http://127.0.0.1:8080'
    Info '      如需重启，请先运行 stop.ps1'
    Write-Host ''
    Read-Host '  按回车退出'
    exit 0
}

# --- 登录状态 ---
$cred = Join-Path $env:USERPROFILE '.zcode-proxy\credentials.json'
if (-not (Test-Path $cred)) {
    Fail '  [X] 尚未登录，无法启动。'
    Warn '      请先执行登录：'
    Write-Host "      & `"$Bun`" run --cwd `"$Proj`" src/index.ts auth login bigmodel" -ForegroundColor Gray
    Write-Host ''
    Read-Host '  按回车退出'
    exit 1
}

# --- 日志目录 ---
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

# --- 启动（无窗口后台） ---
Info '  正在后台启动服务...'
$p = Start-Process -FilePath $Bun `
    -ArgumentList 'run','--cwd',$Proj,'src/index.ts','serve' `
    -RedirectStandardOutput $OutLog `
    -RedirectStandardError $ErrLog `
    -WindowStyle Hidden `
    -PassThru

# --- 等待就绪 ---
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 700
    if ($p.HasExited) { break }
    $listen = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($listen) { $ready = $true; break }
}

Write-Host ''
if ($ready) {
    Ok "  [√] 启动成功"
    Write-Host "      PID     : $($p.Id)"
    Info '      地址    : http://127.0.0.1:8080'
    Info '      密钥    : 见 config.yaml -> auth.proxyApiKey'
    Info "      日志    : $OutLog"
    Write-Host ''
    Info '  停止服务请运行 stop.ps1'
} else {
    Fail '  [X] 启动失败，错误输出：'
    Write-Host ''
    Get-Content $ErrLog -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
}
Write-Host ''
Read-Host '  按回车关闭此窗口'
