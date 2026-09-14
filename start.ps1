# zcode-proxy 前台启动脚本（带实时日志，方便看请求）
# 会占用当前窗口，关闭窗口即停止服务

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = $PSScriptRoot
$Proj = Join-Path $Root '_src\zcode-api-master'
$Bun  = Join-Path $Root '.tools\bun-windows-x64\bun.exe'

Write-Host ''
Write-Host '  ==============================================' -ForegroundColor Cyan
Write-Host '   ZCode Proxy  -  GLM 套餐转标准 API' -ForegroundColor Cyan
Write-Host '  ==============================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $Bun))  { Write-Host "  [X] 找不到 bun: $Bun" -ForegroundColor Red; Read-Host '  按回车退出'; exit 1 }
if (-not (Test-Path $Proj)) { Write-Host "  [X] 找不到项目: $Proj" -ForegroundColor Red; Read-Host '  按回车退出'; exit 1 }

$cred = Join-Path $env:USERPROFILE '.zcode-proxy\credentials.json'
if (-not (Test-Path $cred)) {
    Write-Host '  [!] 尚未登录。请先执行：' -ForegroundColor Yellow
    Write-Host "      & `"$Bun`" run --cwd `"$Proj`" src/index.ts auth login bigmodel" -ForegroundColor Gray
    Write-Host ''
    Read-Host '  按回车退出'
    exit 1
}

$inUse = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($inUse) {
    Write-Host '  [!] 端口 8080 已被占用，服务可能已在运行。' -ForegroundColor Yellow
    Write-Host '      如为后台模式，请先运行 停止服务.ps1' -ForegroundColor Gray
    Write-Host ''
    Read-Host '  按回车退出'
    exit 1
}

Write-Host '  服务地址 : http://127.0.0.1:8080' -ForegroundColor Green
Write-Host '  接入密钥 : 见 config.yaml 的 auth.proxyApiKey' -ForegroundColor Green
Write-Host '  按 Ctrl+C 停止服务' -ForegroundColor Gray
Write-Host ''

Set-Location $Proj
& $Bun run src/index.ts serve
