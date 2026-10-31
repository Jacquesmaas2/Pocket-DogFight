# Exports the browser build to build/web. Usage: .\tools\export_web.ps1 [-Godot path]
param([string]$Godot = $env:GODOT)
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64_console.exe" }
New-Item -ItemType Directory -Force -Path "$root\build\web" | Out-Null
New-Item -ItemType File -Force -Path "$root\build\.gdignore" | Out-Null   # keep the editor from importing build output
& $Godot --headless --path $root --export-release Web "build/web/index.html"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$root\build\web\index.html")) { Write-Error "Web export failed"; exit 1 }
Get-ChildItem "$root\build\web" | Select-Object Name, Length
