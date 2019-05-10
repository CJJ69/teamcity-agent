@echo off

powershell -File configure.ps1
IF %ERRORLEVEL% NEQ 0 (
   echo Failure Reason Given is %ERRORLEVEL%
   exit /b %ERRORLEVEL%
)

powershell -File /BuildAgent/run-agent.ps1
