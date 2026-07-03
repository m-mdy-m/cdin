#Requires -Version 5.1
<#
.SYNOPSIS
    Installs cdin on Windows.

.DESCRIPTION
    - Copies binary + runtime DLLs (SDL3.dll, lua*.dll) + data to %LOCALAPPDATA%\cdin
    - Adds the bin directory to the user PATH
    - Creates a Desktop shortcut (.lnk) and Start Menu entry

.PARAMETER Prefix
    Installation root. Default: %LOCALAPPDATA%\cdin

.PARAMETER BinaryPath
    Path to the already-built cdin.exe.
    Default: auto-detected from build\windows-release\cdin.exe

.PARAMETER DllSearchPaths
    Extra directories to search for SDL3.dll / lua*.dll, in addition to the
    directory that contains BinaryPath and the standard MinGW locations.

.PARAMETER NoPath
    Skip adding the bin directory to the user PATH.

.PARAMETER NoShortcut
    Skip creating desktop / Start Menu shortcuts.

.PARAMETER RegisterFileTypes
    Register cdin as the default application for common text and code file
    extensions (like VS Code does).  Writes under HKCU so no elevation needed.

.PARAMETER Uninstall
    Remove a previous installation made by this script.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]  $Prefix           = (Join-Path $Env:LOCALAPPDATA "cdin"),
    [string]  $BinaryPath       = "",
    [string[]]$DllSearchPaths   = @(),
    [switch]  $NoPath,
    [switch]  $NoShortcut,
    [switch]  $RegisterFileTypes,
    [switch]  $Uninstall
)

$ErrorActionPreference = "Stop"

# ── helpers ───────────────────────────────────────────────────────────────────
function Info  ($msg) { Write-Host "[install] $msg" -ForegroundColor Cyan   }
function Ok    ($msg) { Write-Host "[install] $msg" -ForegroundColor Green  }
function Warn  ($msg) { Write-Host "[install] $msg" -ForegroundColor Yellow }
function Die   ($msg) { Write-Host "[install] ERROR: $msg" -ForegroundColor Red; exit 1 }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir
Push-Location $RootDir

# ── UNINSTALL ─────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Info "Uninstalling cdin from $Prefix …"

    if (Test-Path $Prefix) {
        Remove-Item -Recurse -Force $Prefix
        Ok "Removed $Prefix"
    }

    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $binDir   = Join-Path $Prefix "bin"
    if ($userPath -like "*$binDir*") {
        $newPath = ($userPath -split ";" | Where-Object { $_ -ne $binDir }) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Ok "Removed $binDir from PATH"
    }

    $desktopLnk   = Join-Path ([Environment]::GetFolderPath("Desktop")) "cdin.lnk"
    $startMenuLnk = Join-Path $Env:APPDATA "Microsoft\Windows\Start Menu\Programs\cdin.lnk"
    foreach ($lnk in $desktopLnk, $startMenuLnk) {
        if (Test-Path $lnk) { Remove-Item $lnk -Force; Ok "Removed $lnk" }
    }

    $regRoot = "HKCU:\Software\Classes"
    if (Test-Path "$regRoot\cdin") {
        Remove-Item -Recurse -Force "$regRoot\cdin"
        Ok "Removed HKCU file-type registration"
    }

    Ok "Uninstall complete."
    Pop-Location
    exit 0
}

if ($BinaryPath -eq "") {
    foreach ($candidate in "build\windows-release\cdin.exe", "build\cdin.exe", "cdin.exe", ".\cdin.exe") {
        if (Test-Path $candidate) { $BinaryPath = $candidate; break }
    }
}
if ($BinaryPath -eq "" -or -not (Test-Path $BinaryPath)) {
    Die "cdin.exe not found. Run build.bat first, or pass -BinaryPath <path>."
}
$BinaryPath = (Resolve-Path $BinaryPath).Path
Info "Binary     : $BinaryPath"

function Find-Dll([string[]]$Names) {
    $searchDirs = @(
        (Split-Path -Parent $BinaryPath)
    ) + $DllSearchPaths + (
        $Env:PATH -split ";"
    ) + @(
        "C:\msys64\mingw64\bin",
        "C:\msys64\ucrt64\bin",
        "C:\mingw64\bin",
        "C:\mingw\bin",
        "C:\ProgramData\chocolatey\lib\mingw\tools\install\mingw64\bin"
    )

    foreach ($name in $Names) {
        foreach ($dir in $searchDirs) {
            if ([string]::IsNullOrWhiteSpace($dir)) { continue }
            $candidate = Join-Path $dir $name
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

$binDir  = Join-Path $Prefix "bin"
$dataDir = Join-Path $Prefix "bin\data"

New-Item -ItemType Directory -Force $binDir  | Out-Null
New-Item -ItemType Directory -Force $dataDir | Out-Null

$exeDest = Join-Path $binDir "cdin.exe"
Copy-Item -Force $BinaryPath $exeDest
Ok "Installed binary  → $exeDest"

$sdlDll = Find-Dll @("SDL3.dll")
if ($sdlDll) {
    Copy-Item -Force $sdlDll $binDir
    Ok "Installed SDL3.dll → $binDir"
} else {
    Warn "SDL3.dll not found. Add its directory to -DllSearchPaths or copy it manually to $binDir"
}

$luaDll = Find-Dll @("lua55.dll","lua54.dll","lua5.4.dll","lua53.dll","lua5.3.dll","lua.dll")
if ($luaDll) {
    Copy-Item -Force $luaDll $binDir
    Ok "Installed $([IO.Path]::GetFileName($luaDll)) → $binDir"
} else {
    Warn "Lua DLL not found. Add its directory to -DllSearchPaths or copy it manually to $binDir"
}

if (Test-Path "data") {
    Copy-Item -Recurse -Force "data\*" $dataDir
    Ok "Installed data    → $dataDir"
}

$icoPath      = Join-Path $Prefix "cdin.ico"
$iconSvg      = "scripts\icon.svg"
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

if (Test-Path $iconSvg) {
    $converted = Write-MinimalIco $iconSvg $icoPath
    if ($converted) {
        Ok "Icon              → $icoPath"
        $iconInstalled = $true
    } else {
        Warn "SVG→ICO conversion failed (install cairosvg + Pillow for best results)."
        $icoPath = ""
    }
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

    function New-Shortcut([string]$lnkPath, [string]$target, [string]$desc, [string]$ico) {
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath       = $target
        $lnk.WorkingDirectory = Split-Path $target
        $lnk.Description      = $desc
        if ($ico -ne "") { $lnk.IconLocation = $ico }
        $lnk.Save()
    }

    $desktop   = [Environment]::GetFolderPath("Desktop")
    $startMenu = Join-Path $Env:APPDATA "Microsoft\Windows\Start Menu\Programs"

    New-Shortcut (Join-Path $desktop   "cdin.lnk") $exeDest "cdin – Lightweight Code Editor" $icoPath
    Ok "Desktop shortcut  → $(Join-Path $desktop 'cdin.lnk')"

    New-Shortcut (Join-Path $startMenu "cdin.lnk") $exeDest "cdin – Lightweight Code Editor" $icoPath
    Ok "Start Menu entry  → $(Join-Path $startMenu 'cdin.lnk')"
}

if ($RegisterFileTypes) {
    Info "Registering file-type associations …"

    $regRoot  = "HKCU:\Software\Classes"
    $progId   = "cdin"
    $openCmd  = "`"$exeDest`" `"%1`""

    $progKey = "$regRoot\$progId"
    New-Item -Path $progKey                     -Force | Out-Null
    New-Item -Path "$progKey\DefaultIcon"       -Force | Out-Null
    New-Item -Path "$progKey\shell\open\command" -Force | Out-Null

    Set-ItemProperty -Path $progKey                      -Name "(Default)"  -Value "cdin Document"
    if ($icoPath -ne "") {
        Set-ItemProperty -Path "$progKey\DefaultIcon"    -Name "(Default)"  -Value $icoPath
    }
    Set-ItemProperty -Path "$progKey\shell\open\command" -Name "(Default)"  -Value $openCmd

    $extensions = @(
        # plain text
        ".txt", ".log", ".ini", ".cfg", ".conf",
        # web
        ".html", ".htm", ".css", ".js", ".ts", ".jsx", ".tsx", ".json", ".xml", ".yaml", ".yml",
        # systems / scripts
        ".c", ".h", ".cpp", ".hpp", ".cs", ".rs", ".go", ".py", ".rb", ".sh", ".bat", ".ps1",
        # Lua (cdin's own scripting language)
        ".lua",
        # misc source
        ".md", ".toml", ".sql", ".env", ".gitignore"
    )

    foreach ($ext in $extensions) {
        $extKey = "$regRoot\$ext"

        # Persist any existing default so the user can restore it
        if (Test-Path $extKey) {
            $existing = (Get-ItemProperty -Path $extKey -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
            if ($existing -and $existing -ne $progId) {
                # Save under OpenWithProgids so cdin appears in "Open with" too
                New-Item -Path "$extKey\OpenWithProgids" -Force | Out-Null
                New-ItemProperty -Path "$extKey\OpenWithProgids" -Name $existing -Value ([byte[]]@()) -PropertyType Binary -Force | Out-Null
            }
        } else {
            New-Item -Path $extKey -Force | Out-Null
        }

        Set-ItemProperty -Path $extKey -Name "(Default)" -Value $progId

        # Always add to OpenWithProgids so we appear in right-click → Open with
        New-Item -Path "$extKey\OpenWithProgids" -Force | Out-Null
        New-ItemProperty -Path "$extKey\OpenWithProgids" -Name $progId -Value ([byte[]]@()) -PropertyType Binary -Force | Out-Null
    }

    Ok "Registered $(($extensions).Count) file extensions under HKCU\Software\Classes."
    Info "Tip: right-click any file → 'Open with' → cdin is now listed."
    Info "     To make cdin the default for a specific type, use:"
    Info "     Settings → Apps → Default apps → choose by file type"
}

Pop-Location
Write-Host ""
Ok "Installation complete!"
if (-not $RegisterFileTypes) {
    Info "Tip: re-run with -RegisterFileTypes to set cdin as the default for text/code files."
}
Ok "Open a new terminal and run: cdin"