# Starts a headless dedicated server on this laptop. Usage: .\tools\run_server.ps1 [-Port 24565] [-Transport websocket|enet]
param([int]$Port = 24565, [string]$Transport = "websocket", [string]$Godot = $env:GODOT)
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64_console.exe" }
& $Godot --headless --path $root -- --server --port=$Port --transport=$Transport
