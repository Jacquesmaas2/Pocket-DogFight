# Exports the browser build to export/web. Usage: .\tools\export_web.ps1 [-Godot path]
param([string]$Godot = $env:GODOT)
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64_console.exe" }
New-Item -ItemType Directory -Force -Path "$root\export\web" | Out-Null
& $Godot --headless --path $root --export-release Web "export/web/index.html"
Get-ChildItem "$root\export\web" | Select-Object Name, Length
