@echo off
setlocal
rem Windows PowerShell 5.1 must rebuild its own module path.
rem A CMD hop from PowerShell 7 otherwise inherits incompatible PS7 modules.
set "PSModulePath="
set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PWSH=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-TaskbarMonitorEnhanced.ps1" %*
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo Taskbar Monitor Enhanced installation did not complete. See the reason above.
  if /I "%TBME_PAUSE_ON_ERROR%"=="1" pause
)
exit /b %RESULT%
