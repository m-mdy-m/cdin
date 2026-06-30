@echo off
REM scripts\install.bat — build and "install" cdin on Windows
REM
REM Windows doesn't have a system-wide install convention like Linux's
REM /usr/local, so this just builds a release binary and copies the
REM runtime files (data\, SDL3.dll) next to it in a self-contained
REM folder you can move/zip/run from anywhere.
REM
REM Usage:
REM   scripts\install.bat [destination_folder]
REM   (default destination: dist\cdin)

setlocal
set DEST=%1
if "%DEST%"=="" set DEST=dist\cdin

cd "%~dp0\.."

where make >nul 2>nul
if errorlevel 1 (
  echo error: 'make' not found on PATH.
  echo        Run this from an MSYS2 MinGW64 shell ^(see docs\guides\building.md^).
  exit /b 1
)

echo ==^> make build
make build
if errorlevel 1 exit /b 1

echo ==^> staging to %DEST%
if not exist "%DEST%" mkdir "%DEST%"
copy /Y build\windows-release\cdin.exe "%DEST%\cdin.exe" >nul
xcopy /Y /E /I /Q data "%DEST%\data" >nul

if exist SDL3.dll (
  copy /Y SDL3.dll "%DEST%\SDL3.dll" >nul
) else (
  echo warning: SDL3.dll not found in project root — copy it into %DEST% manually
  echo          ^(see docs\guides\building.md for where it comes from^).
)

echo.
echo Done. Run: %DEST%\cdin.exe

endlocal