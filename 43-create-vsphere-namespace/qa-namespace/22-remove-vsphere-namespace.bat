@echo off
REM -------------+-------------------------------------------------------------------------------------+
REM Script Name ^| 22-remove-vsphere-namespace.bat                                                    ^|
REM Updated     ^| 2026-11-15                                                                         ^|
REM Version     ^| 1.3                                                                                ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                                             ^|
REM Description ^| Submit deletion of one namespace and its workloads.                                ^|
REM -------------+-------------------------------------------------------------------------------------+

REM -------------+-------------------------------------------------------------------------------------+
REM Requirement ^| Details                                                                            ^|
REM -------------+-------------------------------------------------------------------------------------+
REM Runtime     ^| Windows CMD with Windows PowerShell 5.1; delayed expansion disabled.               ^|
REM Tools       ^| curl.exe and jq.exe; checked and installed through WinGet when missing.            ^|
REM Install     ^| WinGet and PowerShell are required for missing-tool installation and PATH refresh. ^|
REM Inputs      ^| Review the editable vCenter connection, credentials and namespace settings.        ^|
REM Access      ^| HTTPS to vCenter; valid credentials and namespace management permissions.          ^|
REM Effect      ^| Deletes the selected namespace and its workloads without a confirmation prompt.    ^|
REM -------------+-------------------------------------------------------------------------------------+

rem Preserve exclamation marks in configured passwords.
setlocal EnableExtensions DisableDelayedExpansion

set "VCENTER=mgmt-vcsa.platformlab.vcf"
set "VC_USER=labadministrator@vsphere.local"
set "VC_PASS=VMwar3!!VMwar3!!"

set "CONNECT_TIMEOUT=10"
set "REQUEST_TIMEOUT=120"

set "NAMESPACE_NAME=qa-namespace"

rem Require Windows PowerShell for refreshing PATH after utility installation.
where powershell.exe >nul 2>&1 || exit /b 1

rem Install curl if missing, then refresh PATH for this script.
where curl.exe >nul 2>&1
if errorlevel 1 (
  rem Require WinGet before installing curl.
  where winget.exe >nul 2>&1 || exit /b 1
  rem Install curl for the current user.
  winget.exe install --id cURL.cURL --exact --source winget --scope user --silent --disable-interactivity --accept-package-agreements --accept-source-agreements || exit /b 1
  rem Add the refreshed user PATH to this script's PATH.
  for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P;%PATH%"
)
rem Confirm curl is available after installation.
where curl.exe >nul 2>&1 || exit /b 1

rem Install jq if missing, then refresh PATH for this script.
where jq.exe >nul 2>&1
if errorlevel 1 (
  rem Require WinGet before installing jq.
  where winget.exe >nul 2>&1 || exit /b 1
  rem Install jq for the current user.
  winget.exe install --id jqlang.jq --exact --source winget --scope user --silent --disable-interactivity --accept-package-agreements --accept-source-agreements || exit /b 1
  rem Add the refreshed user PATH to this script's PATH.
  for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P;%PATH%"
)
rem Confirm jq is available after installation.
where jq.exe >nul 2>&1 || exit /b 1

rem Clear any inherited session token.
set "TOKEN="

rem Create a vCenter API session and read its token without saving it to disk.
for /f "delims=" %%T in ('curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -u "%VC_USER%:%VC_PASS%" -X POST "https://%VCENTER%/api/session" ^| jq.exe -er "strings | select(length > 0)"') do set "TOKEN=%%T"

rem Stop if authentication did not return a session token.
if not defined TOKEN (
  echo No vCenter API session token was returned. 1>&2
  exit /b 1
)

rem Submit deletion of the namespace and its workloads; report acceptance only on success.
curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" -X DELETE "https://%VCENTER%/api/vcenter/namespaces/instances/%NAMESPACE_NAME%" && echo Namespace deletion request accepted: %NAMESPACE_NAME%; removal has not been checked.

rem Retain the namespace request's exit status while closing the session.
set "REQUEST_EXIT_CODE=%ERRORLEVEL%"

rem Close the vCenter API session.
curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" -X DELETE "https://%VCENTER%/api/session"

rem Restore the caller's environment and return the namespace request's exit status.
endlocal & exit /b %REQUEST_EXIT_CODE%
