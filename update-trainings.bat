@echo off
REM ===================================================================
REM  update-trainings.bat  --  double-click after replacing the data file.
REM
REM  Editor-page workflow:
REM    1. In the trainings editor, click "Download updated trainings.json"
REM    2. Put that file in the data\ folder (replace the old one)
REM    3. Double-click THIS file
REM    4. Deploy (or, if Netlify builds on deploy, just push/upload)
REM
REM  It rebuilds index.html and apply.html from data\trainings.json and
REM  then checks that they are fresh. Uses the PowerShell scripts, which
REM  work with or without Node installed.
REM ===================================================================
setlocal
cd /d "%~dp0"

echo Rebuilding pages from data\trainings.json ...
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build-trainings.ps1"
if errorlevel 1 goto :failed

echo.
echo Checking freshness ...
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\check-fresh.ps1"
if errorlevel 1 goto :failed

echo.
echo ===================================================================
echo  Done. index.html and apply.html are rebuilt and FRESH.
echo  Next: deploy the site (or just push/upload if Netlify builds).
echo ===================================================================
pause
exit /b 0

:failed
echo.
echo ===================================================================
echo  Something went wrong above. Do NOT deploy until it says FRESH.
echo ===================================================================
pause
exit /b 1
