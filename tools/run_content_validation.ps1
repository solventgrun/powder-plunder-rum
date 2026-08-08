$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$defaultGodot = Join-Path $projectRoot "..\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { [System.IO.Path]::GetFullPath($defaultGodot) }

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot console executable not found. Set GODOT_BIN to your Godot 4 console executable."
}

$env:APPDATA = Join-Path $projectRoot ".godot-user\appdata"
$env:LOCALAPPDATA = Join-Path $projectRoot ".godot-user\localappdata"
$env:USERPROFILE = Join-Path $projectRoot ".godot-user\profile"
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null

& $godot --headless --path $projectRoot --script "res://tools/validate_content.gd"
exit $LASTEXITCODE
