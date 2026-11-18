@echo off
REM -------------+--------------------------------------------------------------------+
REM Script Name  ^| 12-install-vcf-cli-windows-amd64.bat                               ^|
REM Updated      ^| 2026-11-15                                                         ^|
REM Version      ^| 1.0                                                                ^|
REM VCF Version  ^| 9.1.1.0-545627-2026-09                                             ^|
REM Description  ^| Install VCF CLI, kubectl and plugins for Windows AMD64             ^|
REM              ^| from files already downloaded into the user Downloads folder.      ^|
REM --------------+--------------------------------------------------------------------+

REM --------------+--------------------------------------------------------------------+
REM Requirement  ^| Details                                                            ^|
REM --------------+--------------------------------------------------------------------+
REM Runtime      ^| Windows 10 or 11, AMD64, native Windows Command Prompt.            ^|
REM Tools        ^| Built-in Windows tar.exe and CMD commands; no downloads.           ^|
REM Input        ^| Windows AMD64 CLI ZIP, plugin ZIP and kubectl.exe in Downloads.    ^|
REM Access       ^| Write access to the user profile; no administrator rights needed.  ^|
REM Install path ^| %LOCALAPPDATA%\Programs\vcf.                                       ^|
REM File checks  ^| Exits if any input file is missing, before staging or cleanup.     ^|
REM Cleanup      ^| Resets VCF contexts, configuration, plugins, caches and telemetry. ^|
REM Downloads    ^| Original downloads retained; user staging directory removed.       ^|
REM PATH         ^| Updates the calling CMD PATH; add install path to user PATH        ^|
REM              ^| manually for future terminals.                                     ^|
REM --------------+--------------------------------------------------------------------+

REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+
REM Component                   ^| Architecture  ^| Version    ^| Download URL / Filename                                                ^|
REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+
REM kubectl                     ^| Windows AMD64 ^| v1.33.6    ^| https://dl.k8s.io/release/v1.33.6/bin/windows/amd64/kubectl.exe        ^|
REM VCF Consumption CLI         ^| Windows AMD64 ^| 9.1.1.0100 ^| VCF-Consumption-CLI-Windows_AMD64-9.1.1.0100.25746586.zip              ^|
REM VCF Consumption CLI Plugins ^| Windows AMD64 ^| 9.1.1.0300 ^| VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip ^|
REM ----------------------------+---------------+------------+----------------------------------------------------------------------------+

REM Broadcom Download Path:
REM support.broadcom.com - My Downloads - VMware Cloud Foundation - VMware Cloud Foundation 9.1.1.0

REM Localize installer variables and preserve literal exclamation marks.
setlocal EnableExtensions DisableDelayedExpansion

set "DOWNLOAD_DIR=%USERPROFILE%\Downloads"
set "WORK_DIR=%USERPROFILE%\vcf-cli-install"
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\vcf"

set "VCF_CLI_DOWNLOAD_FILE=%DOWNLOAD_DIR%\VCF-Consumption-CLI-Windows_AMD64-9.1.1.0100.25746586.zip"
set "KUBECTL_DOWNLOAD_FILE=%DOWNLOAD_DIR%\kubectl.exe"
set "VCF_CLI_PLUGIN_DOWNLOAD_FILE=%DOWNLOAD_DIR%\VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip"

REM Require the downloaded VCF CLI archive.
if not exist "%VCF_CLI_DOWNLOAD_FILE%" (echo File not found: "%VCF_CLI_DOWNLOAD_FILE%" 1>&2 & exit /b 1)

REM Require the downloaded kubectl binary.
if not exist "%KUBECTL_DOWNLOAD_FILE%" (echo File not found: "%KUBECTL_DOWNLOAD_FILE%" 1>&2 & exit /b 1)

REM Require the downloaded VCF plugin bundle.
if not exist "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" (echo File not found: "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" 1>&2 & exit /b 1)

REM Remove staging files left by a previous installation attempt.
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"

REM Create separate staging directories for the CLI and plugin bundle.
mkdir "%WORK_DIR%\vcf-cli" "%WORK_DIR%\vcf-plugins"

REM Extract the already downloaded VCF CLI ZIP with built-in Windows tar.
"%SystemRoot%\System32\tar.exe" -xf "%VCF_CLI_DOWNLOAD_FILE%" -C "%WORK_DIR%\vcf-cli"

REM Extract the already downloaded plugin ZIP to its local source directory.
"%SystemRoot%\System32\tar.exe" -xf "%VCF_CLI_PLUGIN_DOWNLOAD_FILE%" -C "%WORK_DIR%\vcf-plugins"

REM Stage the downloaded AMD64 kubectl before resetting VCF configuration.
copy /y "%KUBECTL_DOWNLOAD_FILE%" "%WORK_DIR%\kubectl.exe" >nul

REM Announce the reset of existing VCF settings and saved contexts.
echo Cleaning up local VCF CLI configuration and saved contexts...

REM Remove the existing VCF cache.
if exist "%USERPROFILE%\.cache\vcf" rmdir /s /q "%USERPROFILE%\.cache\vcf"

REM Remove existing VCF configuration and saved contexts.
if exist "%USERPROFILE%\.config\vcf" rmdir /s /q "%USERPROFILE%\.config\vcf"

REM Remove existing VCF telemetry configuration.
if exist "%USERPROFILE%\.config\vcf-cli-telemetry" rmdir /s /q "%USERPROFILE%\.config\vcf-cli-telemetry"

REM Remove existing VCF CLI shared data.
if exist "%USERPROFILE%\.local\share\vcf-cli" rmdir /s /q "%USERPROFILE%\.local\share\vcf-cli"

REM Remove existing local VCF data and plugins.
if exist "%USERPROFILE%\.local\vcf" rmdir /s /q "%USERPROFILE%\.local\vcf"

REM Remove existing local VCF telemetry data.
if exist "%USERPROFILE%\.local\vcf-cli-telemetry" rmdir /s /q "%USERPROFILE%\.local\vcf-cli-telemetry"

REM Announce the VCF CLI installation.
echo Installing VCF CLI...

REM Create the current-user installation directory.
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Install the extracted Windows AMD64 VCF CLI binary.
copy /y "%WORK_DIR%\vcf-cli\vcf-cli-windows_amd64.exe" "%INSTALL_DIR%\vcf.exe" >nul

REM Make the installed utilities available during this installation.
set "PATH=%INSTALL_DIR%;%PATH%"

REM Display the installed VCF CLI version.
"%INSTALL_DIR%\vcf.exe" version

REM Announce the kubectl installation.
echo Installing kubectl...

REM Install the staged Windows AMD64 kubectl binary.
copy /y "%WORK_DIR%\kubectl.exe" "%INSTALL_DIR%\kubectl.exe" >nul

REM Display the installed kubectl client version.
"%INSTALL_DIR%\kubectl.exe" version --client=true

REM Announce the local VCF plugin installation.
echo Installing VCF plugins from the local bundle...

REM Install all plugins from the extracted local bundle.
"%INSTALL_DIR%\vcf.exe" plugin install all --local-source "%WORK_DIR%\vcf-plugins"

REM List the installed VCF plugins.
"%INSTALL_DIR%\vcf.exe" plugin list

REM Optionally disable automatic plugin-source discovery.
REM "%INSTALL_DIR%\vcf.exe" config set features.global.disable-plugin-source-discovery true

REM Remove only staging files, preserving the original downloads.
rmdir /s /q "%WORK_DIR%"

REM Show the directory to add to the user PATH for future terminals.
echo Add "%INSTALL_DIR%" to your user PATH for future terminals.

REM Retain the updated PATH in the calling CMD session.
endlocal & set "PATH=%PATH%"
