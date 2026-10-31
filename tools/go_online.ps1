# One click "go online" from this laptop: dedicated server + public tunnel + share link on the clipboard.
# Usage: .\tools\go_online.ps1 [-Port 24565]
param([int]$Port = 24565, [string]$Godot = $env:GODOT)
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64_console.exe" }
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) { Write-Error "cloudflared missing: winget install Cloudflare.cloudflared"; exit 1 }
$pages = (Select-String -Path "$root\project.godot" -Pattern 'web_client_url="([^"]+)"').Matches[0].Groups[1].Value

Get-Process | ? { $_.ProcessName -like "Godot*" -and $_.MainWindowHandle -eq 0 } | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process cloudflared -ErrorAction SilentlyContinue | ? { (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*$Port*" } | Stop-Process -Force -ErrorAction SilentlyContinue

$log = "$env:TEMP\pd_tunnel.log"
Remove-Item $log -ErrorAction SilentlyContinue
$srv = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" -- --server --port=$Port --transport=websocket" -PassThru -NoNewWindow
$tun = Start-Process cloudflared -ArgumentList "tunnel --url http://localhost:$Port" -PassThru -NoNewWindow -RedirectStandardError $log
$url = $null
for ($i = 0; $i -lt 30 -and -not $url; $i++) {
    Start-Sleep 1
    if (Test-Path $log) { $url = (Get-Content $log | Select-String -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -AllMatches).Matches.Value | Select-Object -First 1 }
}
if (-not $url) { Write-Error "Tunnel did not come up"; exit 1 }
$wss = $url -replace "^https://", "wss://"
$link = "$pages`?server=$wss"
Set-Clipboard $link
Write-Host ""
Write-Host "SERVER : $wss" -ForegroundColor Cyan
Write-Host "LINK   : $link  (copied to clipboard)" -ForegroundColor Green
Write-Host "Keep this window open. Ctrl+C stops server and tunnel." -ForegroundColor Yellow
try { Wait-Process -Id $srv.Id } finally { Stop-Process -Id $tun.Id -Force -ErrorAction SilentlyContinue; Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue }
