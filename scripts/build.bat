@echo off
REM =============================================================================
REM  build.bat  –  Windows native build script for cdin
REM  Requires: MSVC (cl.exe) OR MinGW-w64 (gcc), Python 3, GNU make / nmake
REM =============================================================================
setlocal EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
pushd "%ROOT_DIR%"

set "BUILD_TYPE=release"
set "PREFIX=%LOCALAPPDATA%\cdin"
set "JOBS=%NUMBER_OF_PROCESSORS%"
if "%JOBS%"=="" set "JOBS=4"

:parse
if "%~1"=="" goto :done_parse
if /I "%~1"=="--debug"   set "BUILD_TYPE=debug"   & shift & goto :parse
if /I "%~1"=="--release" set "BUILD_TYPE=release" & shift & goto :parse
if /I "%~1"=="/debug"    set "BUILD_TYPE=debug"   & shift & goto :parse
if /I "%~1"=="/release"  set "BUILD_TYPE=release" & shift & goto :parse
if /I "%~1"=="/help"     goto :usage
if /I "%~1"=="--help"    goto :usage
if /I "%~1"=="/?"        goto :usage
echo [build] WARNING: Unknown option: %~1
shift
goto :parse
:done_parse

echo [build] Build type : %BUILD_TYPE%
echo [build] Prefix     : %PREFIX%
echo [build] Jobs       : %JOBS%

set "PYTHON="
for %%C in (python3.exe python.exe py.exe) do (
    for /f "delims=" %%P in ('where %%C 2^>nul') do (
        if not defined PYTHON (
            "%%P" --version 2>&1 | findstr /R "Python 3\." >nul && set "PYTHON=%%P"
        )
    )
)
if not defined PYTHON (
    echo [build] ERROR: Python 3 not found. Install from https://www.python.org/
    exit /b 1
)
echo [build] Python     : %PYTHON%

set "ICON_SVG=scripts\icon.svg"
set "ICON_INL=src\icon.inl"

if exist "%ICON_SVG%" (
    set "DO_GEN=0"
    if not exist "%ICON_INL%" set "DO_GEN=1"
    REM Simple timestamp check: if gen_icon.py is newer, regenerate
    REM (Full timestamp compare needs PowerShell; we just always regenerate if .inl missing)
    if "!DO_GEN!"=="1" (
        echo [build] Generating %ICON_INL% from %ICON_SVG% ...
        "%PYTHON%" scripts\gen_icon.py --svg "%ICON_SVG%" --out "%ICON_INL%"
        if errorlevel 1 (
            echo [build] ERROR: gen_icon.py failed.
            exit /b 1
        )
        echo [build] %ICON_INL% generated.
    ) else (
        echo [build] %ICON_INL% already exists.
    )
) else (
    echo [build] WARNING: %ICON_SVG% not found – skipping icon generation.
)

set "COMPILER="

REM Try MSVC first
where cl.exe >nul 2>&1 && set "COMPILER=msvc"

REM Try MinGW
if not defined COMPILER (
    where gcc.exe >nul 2>&1 && set "COMPILER=mingw"
)

if not defined COMPILER (
    echo [build] ERROR: No C compiler found.
    echo         Install Visual Studio Build Tools or MinGW-w64.
    exit /b 1
)
echo [build] Compiler   : %COMPILER%

set "MAKE="
where mingw32-make.exe >nul 2>&1 && set "MAKE=mingw32-make.exe"
if not defined MAKE (
    where make.exe >nul 2>&1 && set "MAKE=make.exe"
)
if not defined MAKE (
    where nmake.exe >nul 2>&1 && set "MAKE=nmake.exe"
)

if not defined MAKE (
    echo [build] ERROR: make / nmake not found.
    echo         Install MinGW-w64 or Visual Studio Build Tools.
    exit /b 1
)
echo [build] Make       : %MAKE%

echo [build] Running %MAKE% ...
%MAKE% -j%JOBS% BUILD_TYPE=%BUILD_TYPE% PLATFORM=windows PREFIX="%PREFIX%"
if errorlevel 1 (
    echo [build] ERROR: Build failed.
    exit /b 1
)

echo [build] Build complete!
if exist "build\cdin.exe" echo [build] Binary: build\cdin.exe
popd
goto :eof

:usage
echo Usage: build.bat [--debug^|--release] [--help]
echo.
echo Options:
echo   --debug    Build with debug symbols
echo   --release  Optimised release build (default)
echo   --help     Show this help
exit /b 0