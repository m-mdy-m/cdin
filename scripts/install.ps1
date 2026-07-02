#Requires -Version 5.1
<#
.SYNOPSIS
    Installs cdin on Windows.

.DESCRIPTION
    - Copies binary + data to %LOCALAPPDATA%\cdin  (or custom -Prefix)
    - Adds the bin directory to the user PATH
    - Creates a Desktop shortcut  (.lnk)
    - Creates a Start Menu entry
    - Optionally generates icon.inl if missing  (needs Python 3)
.PARAMETER Uninstall
    Remove a previous installation made by this script.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Prefix     = (Join-Path $Env:LOCALAPPDATA "cdin"),
    [string]$BinaryPath = "",
    [switch]$NoPath,
    [switch]$NoShortcut,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# ── helpers ──────────────────────────────────────────────────────────────────
function Info  ($msg) { Write-Host "[install] $msg" -ForegroundColor Cyan    }
function Ok    ($msg) { Write-Host "[install] $msg" -ForegroundColor Green   }
function Warn  ($msg) { Write-Host "[install] $msg" -ForegroundColor Yellow  }
function Die   ($msg) { Write-Host "[install] ERROR: $msg" -ForegroundColor Red; exit 1 }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir
Push-Location $RootDir

# ── UNINSTALL ─────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Info "Uninstalling cdin from $Prefix …"

    # Remove install directory
    if (Test-Path $Prefix) {
        Remove-Item -Recurse -Force $Prefix
        Ok "Removed $Prefix"
    }

    # Remove from PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $binDir   = Join-Path $Prefix "bin"
    if ($userPath -like "*$binDir*") {
        $newPath = ($userPath -split ";" | Where-Object { $_ -ne $binDir }) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Ok "Removed $binDir from PATH"
    }

    # Remove shortcuts
    $desktopLnk   = Join-Path ([Environment]::GetFolderPath("Desktop")) "cdin.lnk"
    $startMenuLnk = Join-Path $Env:APPDATA "Microsoft\Windows\Start Menu\Programs\cdin.lnk"
    foreach ($lnk in $desktopLnk, $startMenuLnk) {
        if (Test-Path $lnk) { Remove-Item $lnk -Force; Ok "Removed $lnk" }
    }

    Ok "Uninstall complete."
    Pop-Location
    exit 0
}

# ── locate binary ─────────────────────────────────────────────────────────────
if ($BinaryPath -eq "") {
    foreach ($candidate in "build\cdin.exe", "cdin.exe", ".\cdin.exe") {
        if (Test-Path $candidate) { $BinaryPath = $candidate; break }
    }
}
if ($BinaryPath -eq "" -or -not (Test-Path $BinaryPath)) {
    Die "cdin.exe not found. Run build.bat first, or pass -BinaryPath <path>."
}
Info "Binary  : $BinaryPath"

# ── ensure icon.inl exists (generate if missing) ──────────────────────────────
$iconInl = "src\icon.inl"
$iconSvg = "scripts\icon.svg"

if (-not (Test-Path $iconInl)) {
    if (Test-Path $iconSvg) {
        $python = $null
        foreach ($cmd in "python3", "python", "py") {
            try {
                $ver = & $cmd --version 2>&1
                if ($ver -match "Python 3") { $python = $cmd; break }
            } catch {}
        }
        if ($python) {
            Info "Generating $iconInl …"
            & $python scripts\gen_icon.py --svg $iconSvg --out $iconInl
            if ($LASTEXITCODE -ne 0) { Warn "gen_icon.py failed – continuing without icon." }
            else { Ok "$iconInl generated." }
        } else {
            Warn "Python 3 not found – $iconInl will not be generated."
        }
    } else {
        Warn "$iconSvg not found – $iconInl will not be generated."
    }
} else {
    Info "$iconInl already exists."
}

$binDir   = Join-Path $Prefix "bin"
$dataDir  = Join-Path $Prefix "bin\data"
$exeDest  = Join-Path $binDir "cdin.exe"

New-Item -ItemType Directory -Force $binDir  | Out-Null
New-Item -ItemType Directory -Force $dataDir | Out-Null

Copy-Item -Force $BinaryPath $exeDest
Ok "Installed binary → $exeDest"

if (Test-Path "data") {
    Copy-Item -Recurse -Force "data\*" $dataDir
    Ok "Installed data   → $dataDir"
}

$icoPath = Join-Path $Prefix "cdin.ico"
$iconInstalled = $false

function Write-MinimalIco([string]$svgPath, [string]$destIco) {
    $python = $null
    foreach ($cmd in "python3", "python", "py") {
        try {
            $ver = & $cmd --version 2>&1
            if ($ver -match "Python 3") { $python = $cmd; break }
        } catch {}
    }
    if (-not $python) { return $false }

    $code = @"
import sys, struct, io
try:
    from PIL import Image
    import cairosvg
    sizes = [256, 64, 48, 32, 16]
    imgs = []
    for sz in sizes:
        png = cairosvg.svg2png(url=r'$svgPath', output_width=sz, output_height=sz)
        imgs.append((sz, Image.open(io.BytesIO(png)).convert('RGBA')))
    n = len(imgs)
    header = struct.pack('<HHH', 0, 1, n)
    dirs = b''; data = b''; off = 6 + 16*n
    for sz, img in imgs:
        buf = io.BytesIO(); img.save(buf, 'PNG'); png = buf.getvalue()
        bw = sz if sz < 256 else 0
        dirs += struct.pack('<BBBBHHII', bw, bw, 0, 0, 1, 32, len(png), off)
        data += png; off += len(png)
    open(r'$destIco', 'wb').write(header + dirs + data)
    print('ok')
except Exception as e:
    print('skip:', e, file=sys.stderr)
"@
    $result = & $python -c $code 2>&1
    return ($result -eq "ok")
}

$iconConverted = Write-MinimalIco $iconSvg $icoPath
if ($iconConverted) {
    Ok "Icon → $icoPath"
    $iconInstalled = $true
} else {
    Warn "Could not convert SVG to ICO (install cairosvg + Pillow for best results)."
    $icoPath = ""
}

if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$binDir;$userPath", "User")
        Ok "Added $binDir to user PATH."
        Warn "Restart your terminal (or run: `$Env:PATH = '$binDir;' + `$Env:PATH`) to use 'cdin'."
    } else {
        Info "$binDir already in PATH."
    }
}

if (-not $NoShortcut) {
    $shell = New-Object -ComObject WScript.Shell

    function New-Shortcut([string]$lnkPath, [string]$target, [string]$description, [string]$ico) {
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath       = $target
        $lnk.WorkingDirectory = Split-Path $target
        $lnk.Description      = $description
        if ($ico -ne "") { $lnk.IconLocation = $ico }
        $lnk.Save()
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $desktopLnk = Join-Path $desktop "cdin.lnk"
    New-Shortcut $desktopLnk $exeDest "cdin – Lightweight Code Editor" $icoPath
    Ok "Desktop shortcut → $desktopLnk"
    $startMenu = Join-Path $Env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    $startLnk  = Join-Path $startMenu "cdin.lnk"
    New-Shortcut $startLnk $exeDest "cdin – Lightweight Code Editor" $icoPath
    Ok "Start Menu entry → $startLnk"
}

Pop-Location
Write-Host ""
Ok "Installation complete!  Open a new terminal and run: cdin"