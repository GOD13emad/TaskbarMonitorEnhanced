@echo off
setlocal
set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PWSH=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PWSH%" -NoLogo -NoProfile -File "%~dp0Install-TaskbarMonitorEnhanced.ps1"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo Taskbar Monitor Enhanced installation did not complete. See the reason above.
  pause
)
exit /b %RESULT%
