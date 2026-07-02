param(
  [string]$Dest = "$env:LocalAppData\cdin",
  [switch]$NoDesktop,
  [switch]$NoBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host ""
Write-Host "=== cdin Windows Installer ===" -ForegroundColor Cyan
Write-Host "  Destination: $Dest"
Write-Host ""

# --- Build ---
if (-not $NoBuild) {
  $make = Get-Command make -ErrorAction SilentlyContinue
  if (-not $make) { $make = Get-Command mingw32-make -ErrorAction SilentlyContinue }
  if (-not $make) {
    Write-Host " ERROR: 'make' not found." -ForegroundColor Red
    Write-Host "  Install MSYS2 (https://www.msys2.org/) and open the MinGW64 shell."
    Write-Host "  Then: pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-SDL3 mingw-w64-x86_64-lua"
    exit 1
  }

  Write-Host "==> Building cdin..." -ForegroundColor Yellow
  & $make.Source build
  if ($LASTEXITCODE -ne 0) { Write-Host "Build failed." -ForegroundColor Red; exit 1 }
}

# --- Copy files ---
Write-Host "==> Staging files to $Dest ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$Exe = "build\windows-release\cdin.exe"
if (-not (Test-Path $Exe)) {
  Write-Host " ERROR: $Exe not found. Did the build succeed?" -ForegroundColor Red; exit 1
}
Copy-Item $Exe "$Dest\cdin.exe" -Force

if (Test-Path "data") {
  Copy-Item "data" "$Dest\data" -Recurse -Force
}

# Find and copy SDL3.dll
$sdlCandidates = @(
  "build\windows-release\SDL3.dll",
  "SDL3.dll",
  "C:\msys64\mingw64\bin\SDL3.dll",
  "C:\msys2\mingw64\bin\SDL3.dll"
)
$sdlSrc = $sdlCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($sdlSrc) {
  Copy-Item $sdlSrc "$Dest\SDL3.dll" -Force
  Write-Host "  Copied SDL3.dll from $sdlSrc"
} else {
  Write-Host "  WARNING: SDL3.dll not found. Copy it to $Dest manually." -ForegroundColor Yellow
}

# --- Add to user PATH ---
Write-Host "==> Updating PATH..." -ForegroundColor Yellow
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$Dest*") {
  [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$Dest", "User")
  Write-Host "  Added $Dest to user PATH."
  Write-Host "  Open a new terminal to use the 'cdin' command."
} else {
  Write-Host "  Already in PATH."
}

# --- Desktop shortcut ---
if (-not $NoDesktop) {
  Write-Host "==> Creating shortcuts..." -ForegroundColor Yellow

  $WshShell = New-Object -ComObject WScript.Shell

  # Desktop
  $DesktopPath = [Environment]::GetFolderPath("Desktop")
  $Shortcut = $WshShell.CreateShortcut("$DesktopPath\cdin.lnk")
  $Shortcut.TargetPath = "$Dest\cdin.exe"
  $Shortcut.WorkingDirectory = $env:USERPROFILE
  $Shortcut.Description = "cdin - Lightweight code editor"
  $Shortcut.Save()
  Write-Host "  Desktop shortcut: $DesktopPath\cdin.lnk"

  # Start Menu
  $StartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
  $Shortcut2 = $WshShell.CreateShortcut("$StartMenu\cdin.lnk")
  $Shortcut2.TargetPath = "$Dest\cdin.exe"
  $Shortcut2.WorkingDirectory = $env:USERPROFILE
  $Shortcut2.Description = "cdin - Lightweight code editor"
  $Shortcut2.Save()
  Write-Host "  Start Menu shortcut created."
}

$Wrapper = "$Dest\cdin.cmd"
@"
@echo off
REM cdin command wrapper
REM Usage: cdin [path|file]
"$Dest\cdin.exe" %*
"@ | Set-Content $Wrapper -Encoding ASCII

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  cdin installed to $Dest" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Terminal (new window after install):"
Write-Host "    cdin              open editor"
Write-Host "    cdin .            open editor here"
Write-Host "    cdin ..\          open one level up"
Write-Host "    cdin file.c       open a file"
Write-Host ""
Write-Host "  Desktop: double-click the cdin icon"
Write-Host ""

# Show popup on success
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
  "cdin installed to:`n$Dest`n`nOpen a new terminal window to use the 'cdin' command.",
  "cdin Installed",
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null