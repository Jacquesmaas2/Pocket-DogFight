# Exposes a locally hosted Pocket Dogfight game to the internet through a tunnel.
# The game host must use the WebSocket transport (default). Share the printed wss:// URL with friends.
# Supports cloudflared (no account needed) or ngrok. Usage: .\tools\start_tunnel.ps1 [-Port 24565] [-Tool cloudflared|ngrok]
param(
    [int]$Port = 24565,
    [ValidateSet("cloudflared", "ngrok", "auto")][string]$Tool = "auto"
)
function Have($n) { return [bool](Get-Command $n -ErrorAction SilentlyContinue) }
if ($Tool -eq "auto") {
    if (Have cloudflared) { $Tool = "cloudflared" } elseif (Have ngrok) { $Tool = "ngrok" } else {
        Write-Host "No tunnel tool found. Install one:" -ForegroundColor Yellow
        Write-Host "  winget install Cloudflare.cloudflared     (free, no account)"
        Write-Host "  winget install ngrok.ngrok                (free account required)"
        exit 1
    }
}
Write-Host "Tunnelling localhost:$Port via $Tool. Keep this window open while hosting." -ForegroundColor Cyan
if ($Tool -eq "cloudflared") {
    Write-Host "Players join with:  wss://<printed-subdomain>.trycloudflare.com" -ForegroundColor Green
    cloudflared tunnel --url "http://localhost:$Port"
} else {
    Write-Host "Players join with the forwarding URL, replacing https:// by wss://" -ForegroundColor Green
    ngrok http $Port
}
