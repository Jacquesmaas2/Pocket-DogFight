# Runs the headless validation suite. Usage: .\tools\run_tests.ps1 [-Godot path\to\godot.exe] [-Net]
param(
    [string]$Godot = $env:GODOT,
    [switch]$Net
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "$env:LOCALAPPDATA\GodotTools\Godot_v4.3-stable_win64_console.exe" }
if (-not (Test-Path $Godot)) { Write-Error "Godot not found. Set -Godot or `$env:GODOT."; exit 1 }

Write-Host "== Import / parse check =="
& $Godot --headless --path $root --import --quit 2>&1 | Select-String -Pattern "ERROR|SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Host $_ -ForegroundColor Red }

Write-Host "== Local tests =="
& $Godot --headless --path $root res://tests/test_runner.tscn
$local = $LASTEXITCODE
if ($Net) {
    foreach ($tr in @("enet", "websocket")) {
        Write-Host "== Two-instance network test ($tr) =="
        $host_proc = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" res://tests/test_runner.tscn -- --net=host --transport=$tr" -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\pd_host_$tr.log"
        Start-Sleep -Seconds 2
        & $Godot --headless --path $root res://tests/test_runner.tscn -- --net=client --transport=$tr
        $client = $LASTEXITCODE
        $host_proc.WaitForExit(40000) | Out-Null
        Get-Content "$env:TEMP\pd_host_$tr.log"
        if ($client -ne 0 -or $host_proc.ExitCode -ne 0) { Write-Host "NETWORK TEST FAILED ($tr)" -ForegroundColor Red; exit 1 }
    }
}
exit $local
