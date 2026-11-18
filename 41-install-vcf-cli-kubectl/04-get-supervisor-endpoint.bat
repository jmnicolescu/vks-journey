@echo off
REM ---------------+----------------------------------------------------------------------------+
REM Script Name   ^| 04-get-supervisor-endpoint.bat                                             ^|
REM Updated       ^| 2026-11-15                                                                 ^|
REM Version       ^| 1.5                                                                        ^|
REM VCF Version   ^| 9.1.1.0-545627-2026-09                                                     ^|
REM Description   ^| Retrieve the Supervisor API endpoint and save Windows environment          ^|
REM               ^| settings.                                                                  ^|
REM ---------------+----------------------------------------------------------------------------+

REM ---------------+----------------------------------------------------------------------------+
REM Requirement   ^| Details                                                                    ^|
REM ---------------+----------------------------------------------------------------------------+
REM Runtime       ^| Windows CMD with command extensions; delayed expansion disabled.           ^|
REM Tools         ^| curl.exe, jq.exe, reg.exe, where.exe and setx.exe.                         ^|
REM Installation  ^| WinGet and package-source access if curl or jq is missing.                 ^|
REM               ^| Installs missing tools for the user and refreshes this script's PATH.      ^|
REM Access        ^| vCenter HTTPS access, valid credentials and Supervisor read permissions.   ^|
REM Configuration ^| Set VCENTER, VC_USER, VC_PASS and CLUSTER_NAME in this script.             ^|
REM Lookup        ^| Requires one matching cluster and one Supervisor in the summary response.  ^|
REM Environment   ^| Writes SUPERVISOR_API_ENDPOINT for the user and calling CMD on success.    ^|
REM TLS           ^| curl -k bypasses vCenter certificate validation for lab use.               ^|
REM ---------------+----------------------------------------------------------------------------+

rem Keep credentials literal and localize temporary variables and PATH changes.
setlocal DisableDelayedExpansion

set "VCENTER=mgmt-vcsa.platformlab.vcf"
set "VC_USER=labadministrator@vsphere.local"
set "VC_PASS=VMwar3!!VMwar3!!"
set "CLUSTER_NAME=platformlab-cl01"

rem Clear lookup results so inherited values cannot be reused.
set "SESSION_ID="
set "CLUSTER_ID="
set "SUPERVISOR_NAME="
set "SUPERVISOR_ENDPOINT="
set "RESULT=1"

rem Install curl if missing, then refresh PATH for this script.
where curl.exe >nul 2>&1
if errorlevel 1 (
  rem Require WinGet before installing curl.
  where winget.exe >nul 2>&1 || exit /b 1
  rem Install curl for the current user.
  winget.exe install --id cURL.cURL --exact --source winget --scope user --silent --disable-interactivity --accept-package-agreements --accept-source-agreements || exit /b 1
  rem Read the user PATH from the registry and expand its environment variables.
  for /f "tokens=2,*" %%A in ('reg.exe query "HKCU\Environment" /v Path 2^>nul') do call set "PATH=%%B;%%PATH%%"
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
  rem Read the user PATH from the registry and expand its environment variables.
  for /f "tokens=2,*" %%A in ('reg.exe query "HKCU\Environment" /v Path 2^>nul') do call set "PATH=%%B;%%PATH%%"
)
rem Confirm jq is available after installation.
where jq.exe >nul 2>&1 || exit /b 1

rem Create a vCenter API session using the source script's lab TLS options.
for /f "delims=" %%T in ('curl.exe -fsSk -X POST -u "%VC_USER%:%VC_PASS%" "https://%VCENTER%/api/session" ^| jq.exe -er ". // empty"') do set "SESSION_ID=%%T"

rem Stop when no session was returned.
if not defined SESSION_ID exit /b 1

rem Resolve exactly one cluster with the configured name.
for /f "delims=" %%C in ('curl.exe -fsSk -G -H "vmware-api-session-id: %SESSION_ID%" --data-urlencode "names=%CLUSTER_NAME%" "https://%VCENTER%/api/vcenter/cluster" ^| jq.exe -er "select(length == 1) | .[].cluster // empty"') do set "CLUSTER_ID=%%C"

rem Log out when the cluster lookup is missing or ambiguous.
if not defined CLUSTER_ID goto logout

rem Retrieve the Supervisor name only when the summary identifies one Supervisor.
for /f "delims=" %%N in ('curl.exe -fsSk -H "vmware-api-session-id: %SESSION_ID%" "https://%VCENTER%/api/vcenter/namespace-management/supervisors/summaries" ^| jq.exe -er ".items | select(length == 1) | .[].info.name // empty"') do set "SUPERVISOR_NAME=%%N"

rem Log out when the Supervisor lookup is missing or ambiguous.
if not defined SUPERVISOR_NAME goto logout

rem Retrieve the selected cluster's nonempty Supervisor API endpoint.
for /f "delims=" %%E in ('curl.exe -fsSk -H "vmware-api-session-id: %SESSION_ID%" "https://%VCENTER%/api/vcenter/namespace-management/clusters/%CLUSTER_ID%" ^| jq.exe -er ".api_server_cluster_endpoint // empty | select(length > 0)"') do set "SUPERVISOR_ENDPOINT=%%E"

rem Leave the saved environment unchanged when no endpoint was returned.
if not defined SUPERVISOR_ENDPOINT goto logout

rem Display the discovered Supervisor, cluster and API endpoint.
echo Supervisor:   %SUPERVISOR_NAME%
echo Cluster:      %CLUSTER_NAME%
echo API endpoint: %SUPERVISOR_ENDPOINT%

rem Persist the endpoint for the current Windows user across sign-ins.
setx SUPERVISOR_API_ENDPOINT "%SUPERVISOR_ENDPOINT%"

rem Retain the result of saving the user environment variable.
set "RESULT=%ERRORLEVEL%"

:logout
rem Log out of vCenter after discovery or a failed lookup.
curl.exe -sk -X DELETE -H "vmware-api-session-id: %SESSION_ID%" "https://%VCENTER%/api/session" >nul

rem Return lookup or persistence failures without exporting an endpoint.
if not "%RESULT%"=="0" exit /b %RESULT%

rem Export the endpoint into the calling CMD session after ending localization.
endlocal & set "SUPERVISOR_API_ENDPOINT=%SUPERVISOR_ENDPOINT%"

rem Return success to the calling CMD session.
exit /b 0
