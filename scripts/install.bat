@echo off
REM ============================================================
REM  cdin Windows installer
REM
REM  Usage:
REM    scripts\install.bat                   (installs to %LocalAppData%\cdin)
REM    scripts\install.bat C:\Tools\cdin     (custom destination)
REM
REM  What this does:
REM    1. Builds cdin (if not already built)
REM    2. Copies cdin.exe + data\ + SDL3.dll to destination
REM    3. Adds destination to your user PATH (no admin needed)
REM    4. Creates a Desktop shortcut (.lnk)
REM    5. Creates a Start Menu shortcut
REM ============================================================
setlocal EnableDelayedExpansion

set DEST=%~1
if "%DEST%"=="" set DEST=%LocalAppData%\cdin

cd /d "%~dp0\.."

REM --- Build first ---
where make >nul 2>nul
if errorlevel 1 where mingw32-make >nul 2>nul
if errorlevel 1 (
  echo  ERROR: 'make' not found. Build cdin first with scripts\build.bat
  echo  from an MSYS2 MinGW64 shell, then re-run this installer.
  exit /b 1
)

echo =^> Building...
call "%~dp0\build.bat"
if errorlevel 1 exit /b 1

REM --- Stage files ---
echo =^> Installing to %DEST%
if not exist "%DEST%" mkdir "%DEST%"

copy /Y "build\windows-release\cdin.exe" "%DEST%\cdin.exe" >nul
if errorlevel 1 (
  echo  ERROR: build\windows-release\cdin.exe not found.
  exit /b 1
)

REM Copy data directory
if exist data (
  xcopy /Y /E /I /Q data "%DEST%\data" >nul
)

REM Copy SDL3.dll
set SDL3_DLL=
if exist "build\windows-release\SDL3.dll"              set SDL3_DLL=build\windows-release\SDL3.dll
if not defined SDL3_DLL if exist "SDL3.dll"            set SDL3_DLL=SDL3.dll
if not defined SDL3_DLL if exist "C:\msys64\mingw64\bin\SDL3.dll" set SDL3_DLL=C:\msys64\mingw64\bin\SDL3.dll
if not defined SDL3_DLL if exist "C:\msys2\mingw64\bin\SDL3.dll"  set SDL3_DLL=C:\msys2\mingw64\bin\SDL3.dll

if defined SDL3_DLL (
  copy /Y "%SDL3_DLL%" "%DEST%\SDL3.dll" >nul
  echo   Copied SDL3.dll
) else (
  echo   WARNING: SDL3.dll not found. Copy it to %DEST%\ manually.
)

REM --- Add to user PATH (no admin required) ---
echo =^> Adding %DEST% to user PATH...
for /f "usebackq tokens=2*" %%A in (`reg query HKCU\Environment /v PATH 2^>nul`) do set CURRENT_PATH=%%B

REM Check if already in PATH
echo !CURRENT_PATH! | findstr /i /c:"%DEST%" >nul 2>nul
if errorlevel 1 (
  if defined CURRENT_PATH (
    set NEW_PATH=!CURRENT_PATH!;%DEST%
  ) else (
    set NEW_PATH=%DEST%
  )
  reg add HKCU\Environment /v PATH /t REG_EXPAND_SZ /d "!NEW_PATH!" /f >nul
  echo   PATH updated. Open a new terminal to use 'cdin' command.
) else (
  echo   Already in PATH.
)

REM --- Create Desktop shortcut using PowerShell ---
echo =^> Creating Desktop shortcut...
set SHORTCUT=%USERPROFILE%\Desktop\cdin.lnk

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell; " ^
  "$s = $ws.CreateShortcut('%SHORTCUT%'); " ^
  "$s.TargetPath = '%DEST%\cdin.exe'; " ^
  "$s.WorkingDirectory = '%%USERPROFILE%%'; " ^
  "$s.Description = 'cdin - Lightweight code editor'; " ^
  "$s.Save()" >nul 2>nul

if exist "%SHORTCUT%" (
  echo   Desktop shortcut created: %SHORTCUT%
) else (
  echo   WARNING: Could not create desktop shortcut ^(PowerShell unavailable?^).
)

REM --- Create Start Menu shortcut ---
set STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs\cdin.lnk

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell; " ^
  "$s = $ws.CreateShortcut('%STARTMENU%'); " ^
  "$s.TargetPath = '%DEST%\cdin.exe'; " ^
  "$s.WorkingDirectory = '%%USERPROFILE%%'; " ^
  "$s.Description = 'cdin - Lightweight code editor'; " ^
  "$s.Save()" >nul 2>nul

if exist "%STARTMENU%" (
  echo   Start Menu shortcut created.
)

REM --- Write a helper cdin.cmd wrapper for "Open here" context menu ---
set WRAPPER=%DEST%\cdin.cmd
(
  echo @echo off
  echo REM cdin wrapper - supports: cdin [path]
  echo REM   cdin .      open editor in current directory
  echo REM   cdin ../    open editor one level up
  echo "%DEST%\cdin.exe" %%*
) > "%WRAPPER%"

REM --- Done ---
echo.
echo  ==================================================
echo   cdin installed to %DEST%
echo  ==================================================
echo.
echo   Terminal usage ^(after opening new cmd/PowerShell^):
echo     cdin              open editor
echo     cdin .            open in current directory
echo     cdin ..\          open one level up
echo     cdin file.c       open a file
echo.
echo   Desktop: double-click the cdin shortcut
echo   Start Menu: search for "cdin"
echo.

REM Notify Windows that PATH changed
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[System.Environment]::GetEnvironmentVariable('PATH','User') | Out-Null; " ^
  "Add-Type -AssemblyName System.Windows.Forms; " ^
  "[System.Windows.Forms.MessageBox]::Show('cdin installed! Open a new terminal to use the cdin command.','cdin Installed',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)" >nul 2>nul

endlocal