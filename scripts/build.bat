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
    if "!DO_GEN!"=="1" (
        echo [build] Generating %ICON_INL% from %ICON_SVG% ...
        "%PYTHON%" scripts\gen_icon.py --svg "%ICON_SVG%" --out "%ICON_INL%"
        if errorlevel 1 (
            echo [build] ERROR: gen_icon.py failed.
            exit /b 1
        )
        echo [build] %ICON_INL% generated.
    ) else (
        echo [build] %ICON_INL% already exists, skipping generation.
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

set "OUT_DIR=build\windows-%BUILD_TYPE%"
set "EXE=%OUT_DIR%\cdin.exe"

if exist "%EXE%" (
    echo [build] Collecting runtime DLLs into %OUT_DIR% ...

    REM SDL3.dll
    set "SDL3_DLL="
    for /f "delims=" %%F in ('where SDL3.dll 2^>nul') do if not defined SDL3_DLL set "SDL3_DLL=%%F"
    if not defined SDL3_DLL (
        REM Fallback: scan common MinGW bin paths
        for %%D in (
            "C:\msys64\mingw64\bin\SDL3.dll"
            "C:\mingw64\bin\SDL3.dll"
            "C:\mingw\bin\SDL3.dll"
        ) do if exist %%D if not defined SDL3_DLL set "SDL3_DLL=%%~D"
    )
    if defined SDL3_DLL (
        copy /Y "!SDL3_DLL!" "%OUT_DIR%\" >nul
        echo [build]   SDL3.dll  ^<-- !SDL3_DLL!
    ) else (
        echo [build] WARNING: SDL3.dll not found – add its directory to PATH
        echo                  or copy it manually to %OUT_DIR%\
    )

    REM lua*.dll  (lua55.dll / lua54.dll / lua5.4.dll / lua.dll)
    set "LUA_DLL="
    for %%N in (lua55.dll lua54.dll lua5.4.dll lua53.dll lua5.3.dll lua.dll) do (
        if not defined LUA_DLL (
            for /f "delims=" %%F in ('where %%N 2^>nul') do if not defined LUA_DLL set "LUA_DLL=%%F"
            if not defined LUA_DLL (
                for %%D in (
                    "C:\msys64\mingw64\bin\%%N"
                    "C:\mingw64\bin\%%N"
                    "C:\mingw\bin\%%N"
                ) do if exist %%D if not defined LUA_DLL set "LUA_DLL=%%~D"
            )
        )
    )
    if defined LUA_DLL (
        copy /Y "!LUA_DLL!" "%OUT_DIR%\" >nul
        echo [build]   lua dll   ^<-- !LUA_DLL!
    ) else (
        echo [build] WARNING: Lua DLL not found – add its directory to PATH
        echo                  or copy it manually to %OUT_DIR%\
    )

    echo [build] Build complete!
    echo [build] Binary: %EXE%
) else (
    echo [build] Build complete! (binary path unknown)
)

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