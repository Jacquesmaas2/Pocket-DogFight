# Serves the exported web build (export/web) over HTTP and optionally exposes it via cloudflared.
# Usage: .\tools\serve_web.ps1 [-Port 8080] [-Tunnel] [-Server wss://game-server-url]
param([int]$Port = 8080, [switch]$Tunnel, [string]$Server = "")
$root = Join-Path (Split-Path -Parent $PSScriptRoot) "export\web"
if (-not (Test-Path "$root\index.html")) { Write-Error "No web build. Run .\tools\export_web.ps1 first."; exit 1 }
$mime = @{ ".html"="text/html"; ".js"="application/javascript"; ".wasm"="application/wasm"; ".pck"="application/octet-stream"; ".png"="image/png"; ".svg"="image/svg+xml"; ".json"="application/json"; ".ico"="image/x-icon" }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/" -ForegroundColor Cyan
if ($Tunnel) {
    $log = "$env:TEMP\pd_webtunnel.log"
    Start-Process cloudflared -ArgumentList "tunnel --url http://localhost:$Port --http-host-header localhost:$Port" -NoNewWindow -RedirectStandardError $log
    Start-Sleep 8
    $url = (Get-Content $log | Select-String -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -AllMatches).Matches.Value | Select-Object -First 1
    if ($Server) { $url = "$url/?server=$Server" }
    Write-Host "PUBLIC WEB URL: $url" -ForegroundColor Green
}
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
    if ($path -eq "") { $path = "index.html" }
    $file = Join-Path $root $path
    $res = $ctx.Response
    $res.Headers["Cross-Origin-Opener-Policy"] = "same-origin"
    $res.Headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    $res.Headers["Cache-Control"] = "no-cache"
    if ((Test-Path $file) -and -not (Get-Item $file).PSIsContainer -and $file.StartsWith($root)) {
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $res.StatusCode = 404
    }
    $res.Close()
}
