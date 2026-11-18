@echo off
REM ------------+------------------------------------------------------------------------------------+
REM Script Name ^| 21-create-vsphere-namespace.bat                                                    ^|
REM Updated     ^| 2026-11-15                                                                         ^|
REM Version     ^| 1.7                                                                                ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                                             ^|
REM Description ^| Create one namespace using the existing standard Supervisor library.               ^|
REM ------------+------------------------------------------------------------------------------------+

REM ------------+------------------------------------------------------------------------------------+
REM Requirement ^| Details                                                                            ^|
REM ------------+------------------------------------------------------------------------------------+
REM Runtime     ^| Windows CMD with Windows PowerShell 5.1; delayed expansion disabled.               ^|
REM Tools       ^| curl.exe and jq.exe; checked and installed through WinGet when missing.            ^|
REM Install     ^| WinGet and PowerShell are required for missing-tool installation and PATH refresh. ^|
REM Inputs      ^| Review the editable vCenter connection, credentials and namespace settings.        ^|
REM Access      ^| HTTPS to vCenter; valid credentials and namespace management permissions.          ^|
REM Resources   ^| Existing Supervisor-enabled cluster, storage policy, VM classes and access group.  ^|
REM Local files ^| Write access to deployment-files beside this script.                               ^|
REM ------------+------------------------------------------------------------------------------------+

REM Namespace permission model (domain: vsphere.local).
REM The Supervisor role is configured separately; this file assigns read-only namespace access.
REM -------------------+---------------------------+---------------------------------------------------+
REM Group             ^| Role                     ^| Assigned at                                      ^|
REM -------------------+---------------------------+---------------------------------------------------+
REM LabUsers          ^| Namespaces View (VIEW)   ^| DEV/QA namespace                                 ^|
REM LabAdministrators ^| Supervisor Administrator ^| Supervisor: lab-supervisor                       ^|
REM -------------------+---------------------------+---------------------------------------------------+

rem Preserve exclamation marks in configured passwords.
setlocal EnableExtensions DisableDelayedExpansion

set "VCENTER=mgmt-vcsa.platformlab.vcf"
set "VC_USER=labadministrator@vsphere.local"
set "VC_PASS=VMwar3!!VMwar3!!"

set "CONNECT_TIMEOUT=10"
set "REQUEST_TIMEOUT=120"
set "DEPLOYMENT_FILES=%~dp0deployment-files"

set "NAMESPACE_NAME=qa-namespace"
set "NAMESPACE_DESCRIPTION=qa-namespace"
set "NAMESPACE_DOMAIN=vsphere.local"
set "NAMESPACE_GROUP=LabUsers"
set "NAMESPACE_ROLE=VIEW"
set "DATACENTER_NAME=platformlab-dc01"
set "CLUSTER_NAME=platformlab-cl01"
set "STORAGE_POLICY_NAME=vSAN Default Storage Policy"

rem Set half of the cluster effective CPU capacity measured on 2026-11-07 (136220 MHz).
set "CPU_LIMIT_MHZ=68110"

rem Set a 300 GiB memory quota per namespace in MiB.
set "MEMORY_LIMIT_MIB=307200"

rem Set a 500 GiB storage quota per namespace and for the assigned storage policy in MiB.
set "STORAGE_LIMIT_MIB=512000"

rem Set the allowed VM classes as a JSON array; quotes are escaped when passed to jq.
set "VM_CLASSES=["best-effort-small","best-effort-medium","best-effort-large","best-effort-xlarge"]"

rem Require Windows PowerShell for refreshing installed utility paths.
where powershell.exe >nul 2>&1 || exit /b 1

rem Refresh machine and user PATH before checking already installed utilities.
for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P;%PATH%"

rem Install curl if missing, then refresh PATH for this script.
where curl.exe >nul 2>&1
if errorlevel 1 (
  rem Require WinGet before installing curl.
  where winget.exe >nul 2>&1 || exit /b 1
  rem Install curl for the current user.
  winget.exe install --id cURL.cURL --exact --source winget --scope user --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
  rem Refresh machine and user PATH even when WinGet reports the package is installed.
  for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P;%PATH%"
)
rem Stop only if curl is still unavailable after refreshing PATH.
where curl.exe >nul 2>&1 || exit /b 1

rem Install jq if missing, then refresh PATH for this script.
where jq.exe >nul 2>&1
if errorlevel 1 (
  rem Require WinGet before installing jq.
  where winget.exe >nul 2>&1 || exit /b 1
  rem Install jq for the current user.
  winget.exe install --id jqlang.jq --exact --source winget --scope user --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
  rem Refresh machine and user PATH even when WinGet reports the package is installed.
  for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P;%PATH%"
)
rem Stop only if jq is still unavailable after refreshing PATH.
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

rem Clear any inherited datacenter identifier.
set "DATACENTER_ID="

rem Find exactly one configured datacenter.
for /f "delims=" %%I in ('curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" "https://%VCENTER%/api/vcenter/datacenter" ^| jq.exe -er --arg name "%DATACENTER_NAME%" "map(select(.name == $name)) | select(length == 1) | .[0].datacenter // empty"') do set "DATACENTER_ID=%%I"

rem Stop on a missing or ambiguous datacenter lookup.
if not defined DATACENTER_ID (
  echo Expected exactly one datacenter matching %DATACENTER_NAME%. 1>&2
  exit /b 1
)

rem Clear any inherited cluster identifier.
set "CLUSTER_ID="

rem Find exactly one configured cluster in the configured datacenter.
for /f "delims=" %%I in ('curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" "https://%VCENTER%/api/vcenter/cluster?datacenters=%DATACENTER_ID%" ^| jq.exe -er --arg name "%CLUSTER_NAME%" "map(select(.name == $name)) | select(length == 1) | .[0].cluster // empty"') do set "CLUSTER_ID=%%I"

rem Stop on a missing or ambiguous cluster lookup.
if not defined CLUSTER_ID (
  echo Expected exactly one cluster in the configured datacenter matching %CLUSTER_NAME%. 1>&2
  exit /b 1
)

rem Clear any inherited policy identifier.
set "STORAGE_POLICY_ID="

rem Find exactly one configured storage policy.
for /f "delims=" %%I in ('curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" "https://%VCENTER%/api/vcenter/storage/policies" ^| jq.exe -er --arg name "%STORAGE_POLICY_NAME%" "map(select(.name == $name)) | select(length == 1) | .[0].policy // empty"') do set "STORAGE_POLICY_ID=%%I"

rem Stop on a missing or ambiguous policy lookup.
if not defined STORAGE_POLICY_ID (
  echo Expected exactly one storage policy matching %STORAGE_POLICY_NAME%. 1>&2
  exit /b 1
)

rem Create the deployment files directory beside this script.
if not exist "%DEPLOYMENT_FILES%\" mkdir "%DEPLOYMENT_FILES%"

rem Build and save the namespace access, storage, VM service, name and description payload.
jq.exe -n --arg cluster "%CLUSTER_ID%" --arg policy "%STORAGE_POLICY_ID%" --argjson limit %STORAGE_LIMIT_MIB% --argjson cpu %CPU_LIMIT_MHZ% --argjson memory %MEMORY_LIMIT_MIB% --argjson classes "%VM_CLASSES:"=\"%" --arg domain "%NAMESPACE_DOMAIN%" --arg group "%NAMESPACE_GROUP%" --arg role "%NAMESPACE_ROLE%" --arg subject_type GROUP --arg name "%NAMESPACE_NAME%" --arg description "%NAMESPACE_DESCRIPTION%" "{cluster:$cluster, access_list:[{domain:$domain, subject:$group, subject_type:$subject_type, role:$role}], resource_spec:{cpu_limit:$cpu, memory_limit:$memory, storage_request_limit:$limit}, storage_specs:[{policy:$policy, limit:$limit}], vm_service_spec:{vm_classes:$classes}, namespace:$name, description:$description}" > "%DEPLOYMENT_FILES%\%NAMESPACE_NAME%.json"

rem Print the saved namespace payload before submitting the creation request.
jq.exe . "%DEPLOYMENT_FILES%\%NAMESPACE_NAME%.json"

rem Submit the saved namespace payload and report acceptance only on success.
curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" -H "Content-Type: application/json" -X POST "https://%VCENTER%/api/vcenter/namespaces/instances" --data-binary "@%DEPLOYMENT_FILES%\%NAMESPACE_NAME%.json" && echo Namespace creation request accepted: %NAMESPACE_NAME%

rem Retain the namespace request's exit status while closing the session.
set "REQUEST_EXIT_CODE=%ERRORLEVEL%"

rem Close the vCenter API session.
curl.exe -fkSs --connect-timeout %CONNECT_TIMEOUT% --max-time %REQUEST_TIMEOUT% -H "vmware-api-session-id: %TOKEN%" -X DELETE "https://%VCENTER%/api/session"

rem Restore the caller's environment and return the namespace request's exit status.
endlocal & exit /b %REQUEST_EXIT_CODE%
