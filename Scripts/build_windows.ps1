param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Set-Location $Root

& $Python -m pip install --upgrade pip
& $Python -m pip install -r python/requirements-build.txt
& $Python -m unittest discover -s python/tests -p "test_*.py"

Set-Location python
& $Python -m PyInstaller --noconfirm convertaderta.spec

New-Item -ItemType Directory -Force -Path ..\dist\windows | Out-Null
Copy-Item dist\convertaderta.exe ..\dist\windows\convertaderta.exe -Force
Compress-Archive -Path ..\dist\windows\convertaderta.exe -DestinationPath ..\dist\convertaderta-windows.zip -Force

Write-Host "Windows build ready:"
Write-Host "  $($Root)\dist\windows\convertaderta.exe"
Write-Host "  $($Root)\dist\convertaderta-windows.zip"
