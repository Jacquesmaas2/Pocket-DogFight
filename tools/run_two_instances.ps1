# Starts two game windows for local multiplayer testing (host + client). Usage: .\tools\run_two_instances.ps1
param([string]$Godot = $env:GODOT)
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64.exe" }
Start-Process $Godot -ArgumentList "--path `"$root`" --position 40,60"
Start-Sleep -Milliseconds 800
Start-Process $Godot -ArgumentList "--path `"$root`" --position 700,120"
Write-Host "Window 1: Host Game -> Start Hosting -> (wait).  Window 2: Join Game -> 127.0.0.1 -> Connect.  Then Start Match in window 1."
