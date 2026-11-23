param([string]$Godot = "")
$ErrorActionPreference = 'Stop'
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
    else { $Godot = Join-Path $env:TEMP 'ashen-godot-4.7.2\Godot_v4.7.2-stable_win64.exe' }
}
if (-not (Test-Path -LiteralPath $Godot)) {
    throw '请安装 Godot 4.7.2，或使用 -Godot 参数指定可执行文件。'
}
$projectPath = Join-Path $PSScriptRoot 'mobile'
# Visible window is intentional: this launcher opens the interactive art preview.
Start-Process -FilePath $Godot -ArgumentList @('--path', ('"' + $projectPath + '"'), '--resolution', '1280x900', 'res://ink_preview.tscn') -WindowStyle Normal
