# zcode-proxy 停止脚本

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ''
Write-Host '  ==============================================' -ForegroundColor Cyan
Write-Host '   ZCode Proxy  -  停止服务' -ForegroundColor Cyan
Write-Host '  ==============================================' -ForegroundColor Cyan
Write-Host ''

$conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue

if (-not $conn) {
    Write-Host '  [!] 服务未在运行' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  按回车退出'
    exit 0
}

$pids = $conn | Select-Object -ExpandProperty OwningProcess -Unique

foreach ($procId in $pids) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "  正在停止 PID $procId ($($p.ProcessName))..." -ForegroundColor Cyan
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    }
}

Start-Sleep -Seconds 1

# 清理残留的 bun 进程
Get-Process bun -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like '*\反代\.tools\*'
} | ForEach-Object {
    Write-Host "  清理残留进程 PID $($_.Id)..." -ForegroundColor Gray
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Write-Host ''
$still = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($still) {
    Write-Host '  [!] 端口 8080 仍被占用' -ForegroundColor Yellow
} else {
    Write-Host '  [√] 服务已停止' -ForegroundColor Green
}
Write-Host ''
Read-Host '  按回车关闭此窗口'
