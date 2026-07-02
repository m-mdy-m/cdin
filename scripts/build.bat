@echo off
REM ============================================================
REM  cdin Windows build script
REM  Run from an MSYS2 MinGW64 shell OR a normal cmd/PowerShell.
REM
REM  Usage:
REM    scripts\build.bat           (release build)
REM    scripts\build.bat debug     (debug build)
REM
REM  Prerequisites (MSYS2 MinGW64):
REM    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make
REM    pacman -S mingw-w64-x86_64-SDL3 mingw-w64-x86_64-lua
REM    (or see docs\guides\building.md for manual SDL3 setup)
REM ============================================================
setlocal EnableDelayedExpansion

set MODE=%~1
if "%MODE%"=="" set MODE=build

cd /d "%~dp0\.."

REM --- Check for make ---
where make >nul 2>nul
if errorlevel 1 (
  where mingw32-make >nul 2>nul
  if errorlevel 1 (
    echo.
    echo  ERROR: 'make' not found on PATH.
    echo.
    echo  This project requires MSYS2 MinGW64. Steps:
    echo    1. Install MSYS2 from https://www.msys2.org/
    echo    2. Open "MSYS2 MinGW64" shell from Start Menu
    echo    3. Run: pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make
    echo    4. Run: pacman -S mingw-w64-x86_64-SDL3 mingw-w64-x86_64-lua
    echo    5. Run this script again from that shell.
    echo.
    exit /b 1
  )
  set MAKE=mingw32-make
) else (
  set MAKE=make
)

echo =^> %MAKE% %MODE%
%MAKE% %MODE%
if errorlevel 1 (
  echo.
  echo  BUILD FAILED. Check output above.
  exit /b 1
)

echo =^> %MAKE% info
%MAKE% info

REM --- Copy SDL3.dll next to the exe so it runs outside MSYS2 shell ---
set OUT_DIR=build\windows-release
if "%MODE%"=="debug" set OUT_DIR=build\windows-debug

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM Try to find SDL3.dll: project root first, then MSYS2 locations
set SDL3_DLL=
if exist "SDL3.dll"                                       set SDL3_DLL=SDL3.dll
if not defined SDL3_DLL if exist "C:\msys64\mingw64\bin\SDL3.dll"  set SDL3_DLL=C:\msys64\mingw64\bin\SDL3.dll
if not defined SDL3_DLL if exist "C:\msys2\mingw64\bin\SDL3.dll"   set SDL3_DLL=C:\msys2\mingw64\bin\SDL3.dll

if defined SDL3_DLL (
  if not exist "%OUT_DIR%\SDL3.dll" (
    copy /Y "%SDL3_DLL%" "%OUT_DIR%\SDL3.dll" >nul
    echo Copied SDL3.dll to %OUT_DIR%\
  )
) else (
  echo.
  echo  WARNING: SDL3.dll not found automatically.
  echo  Copy SDL3.dll manually to %OUT_DIR%\ before distributing.
  echo  (Get it from: https://github.com/libsdl-org/SDL/releases)
)

echo.
echo  Build complete: %OUT_DIR%\cdin.exe
echo.
endlocal