@echo off
REM scripts\build.bat — build cdin on Windows (MSYS2/MinGW shell)
REM
REM This expects an MSYS2 MinGW64 shell with `make`, `gcc`, and the SDL3
REM mingw devel package already extracted (see docs\guides\building.md).
REM Run it from the project root, or from anywhere — it cd's there itself.
REM
REM Usage:
REM   scripts\build.bat
REM   scripts\build.bat debug

setlocal
set MODE=%1
if "%MODE%"=="" set MODE=build

cd "%~dp0\.."

where make >nul 2>nul
if errorlevel 1 (
  echo error: 'make' not found on PATH.
  echo        Run this from an MSYS2 MinGW64 shell ^(see docs\guides\building.md^).
  exit /b 1
)

echo ==^> make %MODE%
make %MODE%
if errorlevel 1 exit /b 1

echo ==^> make info
make info

REM SDL3.dll must sit next to cdin.exe to run outside the dev shell.
if exist SDL3.dll (
  if not exist build\windows-release\SDL3.dll (
    copy /Y SDL3.dll build\windows-release\SDL3.dll >nul
  )
)

endlocal