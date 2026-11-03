# Builds the patched Windows Stats (CPU + GPU temps on the strip) and swaps it into the
# installed copy. No admin rights needed. Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File D:\work\git\windows-stats\build-install.ps1
param(
    [string]$InstallDir = "C:\Users\warre\OneDrive\Documents\WindowsStats-0.1.2-x64"
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

# use the already-installed 1.99.1 GNU toolchain instead of letting rustup fetch the pinned 1.99.0
$env:RUSTUP_TOOLCHAIN = 'stable-x86_64-pc-windows-gnu'
# windres / ar from llvm-mingw so the icon, version info and DPI manifest get embedded
$env:WINDRES = Join-Path $root '.toolchain\llvm-mingw\bin\x86_64-w64-mingw32-windres.exe'
$env:AR = Join-Path $root '.toolchain\llvm-mingw\bin\llvm-ar.exe'

& cargo build --release
if ($LASTEXITCODE -ne 0) { throw "cargo build failed ($LASTEXITCODE)" }
$exe = Join-Path $root 'target\release\WindowsStats.exe'
if (-not (Test-Path $exe)) { throw "no output: $exe" }
Write-Host "Built: $exe ($([math]::Round((Get-Item $exe).Length / 1KB)) KB)"

$target = Join-Path $InstallDir 'WindowsStats.exe'
if (-not (Test-Path $target)) { throw "installed exe not found: $target" }

# close the running app cleanly, keep a backup of the original, drop the new build in, restart
& $target --quit
Start-Sleep -Seconds 3
Get-Process -Name 'WindowsStats', 'WindowsStats.Sensors' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$backup = Join-Path $InstallDir 'WindowsStats.exe.orig-0.1.2'
if (-not (Test-Path $backup)) { Copy-Item $target $backup }
Copy-Item $exe $target -Force
Write-Host "Installed to $target (original kept as $backup)"
Start-Process -FilePath $target -WorkingDirectory $InstallDir
Write-Host 'Windows Stats restarted.'
