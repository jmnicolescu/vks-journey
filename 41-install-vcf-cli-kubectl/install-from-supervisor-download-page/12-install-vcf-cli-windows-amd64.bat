@echo off
REM -------------+-----------------------------------------------------------------------+
REM Script Name  ^| 12-install-vcf-cli-windows-amd64.bat                                ^|
REM Updated      ^| 2026-11-15                                                          ^|
REM Version      ^| 1.11                                                                ^|
REM VCF Version  ^| 9.1.1.0-545627-2026-09                                              ^|
REM Description  ^| Install VCF CLI, kubectl and local VCF plugins for Windows AMD64.   ^|
REM -------------+-----------------------------------------------------------------------+

REM -------------+-----------------------------------------------------------------------+
REM Requirement  ^| Details                                                             ^|
REM -------------+-----------------------------------------------------------------------+
REM Runtime      ^| Windows 10 or 11 CMD on AMD64.                                      ^|
REM Tools        ^| curl.exe, tar.exe or 7z.exe, reg.exe, where.exe and findstr.exe.    ^|
REM Installation ^| WinGet if curl or a ZIP extractor is missing.                       ^|
REM              ^| Installing the 7-Zip fallback requires administrator approval.      ^|
REM Endpoint     ^| Set SUPERVISOR_API_ENDPOINT directly in this script.                ^|
REM Access       ^| Supervisor HTTPS access; write local user programs and user PATH.   ^|
REM Input        ^| Local Broadcom Support plugin ZIP for Windows AMD64.                ^|
REM Staging      ^| Uses the user profile directory: vcf-cli-install.                   ^|
REM Cleanup      ^| Removes staging files and existing VCF configuration and caches.    ^|
REM              ^| Also removes VCF plugin sources and telemetry directories.          ^|
REM Environment  ^| Updates current session PATH and saves the Windows user PATH.       ^|
REM              ^| Sign out and back in for other applications to load the saved PATH. ^|
REM TLS          ^| curl -k bypasses Supervisor certificate validation for lab use.     ^|
REM -------------+-----------------------------------------------------------------------+

REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+
REM Component                   ^| Architecture  ^| Version    ^| Download Source                                                        ^|
REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+
REM kubectl + vSphere Plugin    ^| Windows AMD64 ^| Supervisor ^| Supervisor - vsphere-plugin.zip                                        ^|
REM VCF CLI                     ^| Windows AMD64 ^| 9.1.1.0    ^| Supervisor - vcf-cli.zip                                               ^|
REM VCF Consumption CLI Plugins ^| Windows AMD64 ^| 9.1.1.0300 ^| VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip ^|
REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+

rem Localize installer variables and preserve literal exclamation marks.
setlocal EnableExtensions DisableDelayedExpansion

rem Set the Supervisor endpoint used for package downloads.
set "SUPERVISOR_API_ENDPOINT=10.55.16.4"

set "WORK_DIR=%USERPROFILE%\vcf-cli-install"
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\vcf"
set "VCF_CLI_DOWNLOAD_URL=vcf-cli/v9.1.1.0/25662425/windows/amd64/vcf-cli.zip"
set "KUBECTL_DOWNLOAD_URL=plugin/windows-amd64/vsphere-plugin.zip"
set "VCF_CLI_PLUGIN_DOWNLOAD_FILE=%USERPROFILE%\Downloads\VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip"

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

rem Check for a tar implementation that supports the ZIP packages.
set "USE_TAR="
where tar.exe >nul 2>&1
if not errorlevel 1 (
  rem Windows tar identifies itself as bsdtar; GNU tar cannot extract ZIP files.
  tar.exe --version 2>nul | findstr.exe /i /c:"bsdtar" >nul
  if not errorlevel 1 set "USE_TAR=1"
)

rem Install the ZIP-compatible 7-Zip fallback if Windows tar is unavailable.
set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined USE_TAR (
  if not exist "%SEVENZIP%" (
    rem Require WinGet before installing the fallback extractor.
    where winget.exe >nul 2>&1 || exit /b 1
    rem Install 7-Zip for Windows AMD64 in the selected directory.
    winget.exe install --id 7zip.7zip --exact --source winget --scope machine --architecture x64 --location "%ProgramFiles%\7-Zip" --silent --disable-interactivity --accept-package-agreements --accept-source-agreements || exit /b 1
  )
  rem Confirm that the fallback extractor is available before downloading packages.
  if not exist "%SEVENZIP%" exit /b 1
)

rem Require the Broadcom Support plugin bundle before resetting configuration.
if not exist "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" (
  echo Plugin bundle not found: %VCF_CLI_PLUGIN_DOWNLOAD_FILE% 1>&2
  exit /b 1
)

rem Remove staging files left by a previous installation attempt.
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"

rem Create separate staging directories for the CLI and plugin bundle.
mkdir "%WORK_DIR%\vcf-cli" || exit /b 1
mkdir "%WORK_DIR%\vcf-plugins" || exit /b 1

rem Create the kubectl extraction directory.
mkdir "%WORK_DIR%\vsphere-plugin" || exit /b 1

rem Download the Supervisor packages.
curl.exe -kfSL "https://%SUPERVISOR_API_ENDPOINT%/wcp/%VCF_CLI_DOWNLOAD_URL%" -o "%WORK_DIR%\vcf-cli\vcf-cli.zip" || exit /b 1
curl.exe -kfSL "https://%SUPERVISOR_API_ENDPOINT%/wcp/%KUBECTL_DOWNLOAD_URL%" -o "%WORK_DIR%\vsphere-plugin.zip" || exit /b 1

rem Extract the VCF CLI package with the available ZIP extractor.
if defined USE_TAR (
  tar.exe -xf "%WORK_DIR%\vcf-cli\vcf-cli.zip" -C "%WORK_DIR%\vcf-cli" || exit /b 1
) else (
  "%SEVENZIP%" x -y "%WORK_DIR%\vcf-cli\vcf-cli.zip" "-o%WORK_DIR%\vcf-cli" || exit /b 1
)

rem Extract the vSphere plugin package with the available ZIP extractor.
if defined USE_TAR (
  tar.exe -xf "%WORK_DIR%\vsphere-plugin.zip" -C "%WORK_DIR%\vsphere-plugin" || exit /b 1
) else (
  "%SEVENZIP%" x -y "%WORK_DIR%\vsphere-plugin.zip" "-o%WORK_DIR%\vsphere-plugin" || exit /b 1
)

rem Extract the Broadcom Support plugin bundle with the available ZIP extractor.
if defined USE_TAR (
  tar.exe -xf "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" -C "%WORK_DIR%\vcf-plugins" || exit /b 1
) else (
  "%SEVENZIP%" x -y "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" "-o%WORK_DIR%\vcf-plugins" || exit /b 1
)

rem Remove old VCF CLI configuration, plugin sources, caches and telemetry.
for %%D in ("%USERPROFILE%\.cache\vcf" "%USERPROFILE%\.config\vcf" "%USERPROFILE%\.config\vcf-cli-telemetry" "%USERPROFILE%\.local\share\vcf-cli" "%USERPROFILE%\.local\vcf" "%USERPROFILE%\.local\vcf-cli-telemetry") do (
  if exist "%%~D" rmdir /s /q "%%~D"
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" || exit /b 1

rem Install VCF CLI for Windows AMD64.
copy /y "%WORK_DIR%\vcf-cli\vcf-cli-windows_amd64.exe" "%INSTALL_DIR%\vcf.exe" >nul || exit /b 1
"%INSTALL_DIR%\vcf.exe" version || exit /b 1

rem Install kubectl from the Windows AMD64 vSphere plugin package.
copy /y "%WORK_DIR%\vsphere-plugin\bin\kubectl.exe" "%INSTALL_DIR%\kubectl.exe" >nul || exit /b 1
"%INSTALL_DIR%\kubectl.exe" version --client=true || exit /b 1

rem Make the installed tools available to this script.
set "PATH=%INSTALL_DIR%;%PATH%"

rem Read the saved user PATH without expanding its environment references.
set "USER_PATH="
for /f "tokens=2,*" %%A in ('reg.exe query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"

rem Check whether the installation directory is already in the saved user PATH.
set "INSTALL_DIR_IN_PATH="
for %%D in ("%USER_PATH:;=" "%") do if /i "%%~D"=="%INSTALL_DIR%" set "INSTALL_DIR_IN_PATH=1"

rem Add the installation directory once, preserving the existing user PATH.
if not defined INSTALL_DIR_IN_PATH (
  reg.exe add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "%INSTALL_DIR%;%USER_PATH%" /f >nul || exit /b 1
)

rem Install the local Windows plugins.
"%INSTALL_DIR%\vcf.exe" plugin install all --local-source "%WORK_DIR%\vcf-plugins" || exit /b 1
"%INSTALL_DIR%\vcf.exe" plugin list || exit /b 1

rem Remove downloaded and extracted installation files.
rmdir /s /q "%WORK_DIR%" || exit /b 1
echo Installed VCF CLI and kubectl in %INSTALL_DIR%.
echo Sign out and back in to refresh PATH in other applications.

rem Keep the updated PATH available in the calling CMD session.
endlocal & set "PATH=%PATH%"
exit /b 0
