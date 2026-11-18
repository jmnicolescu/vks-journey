#Requires -Version 7.0
#-------------+-------------------------------------------------------------------+
# Script Name | 13-install-vcf-cli-windows-amd64-ps7.ps1                          |
# Updated     | 2026-11-15                                                        |
# Version     | 1.6                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                            |
# Description | Install VCF CLI, kubectl and local VCF plugins for Windows AMD64. |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Runtime     | PowerShell 7 or newer on Windows AMD64.                           |
# Tools       | Invoke-WebRequest, Expand-Archive and native PowerShell commands. |
# Endpoint    | Set SUPERVISOR_API_ENDPOINT directly in this script.              |
# Access      | Supervisor HTTPS access; write local user programs and user PATH. |
# Input       | Local Broadcom Support plugin ZIP for Windows AMD64.              |
# Staging     | Uses the user profile directory: vcf-cli-install.                 |
# Cleanup     | Removes staging files and existing VCF configuration and caches.  |
#             | Also removes VCF plugin sources and telemetry directories.        |
# Environment | Updates current session PATH and saves the Windows user PATH.     |
# Profile     | Preserves the PowerShell profile and adds the kubectl alias once. |
# TLS         | Skips Supervisor certificate validation for lab use.              |
#-------------+-------------------------------------------------------------------+

# ------------------------------------------------------------------------------------------------------
# If execution is blocked because this script is unsigned, run these commands
# in your PowerShell terminal before launching the script:
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#
# Permanently allow unsigned scripts, including scripts on mapped network drives,
# for the current user. Group Policy settings still take precedence.
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
# ------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------
# Install PowerShell 7 alongside Windows PowerShell 5.1.
# After installation, run 'pwsh' in a new terminal to start PowerShell 7.
# winget install --id Microsoft.PowerShell --source winget
# ------------------------------------------------------------------------------------------------------

#-----------------------------+---------------+------------+------------------------------------------------------------------------+
# Component                   | Architecture  | Version    | Download Source                                                        |
#-----------------------------+---------------+------------+------------------------------------------------------------------------+
# kubectl + vSphere Plugin    | Windows AMD64 | Supervisor | Supervisor - vsphere-plugin.zip                                        |
# VCF CLI                     | Windows AMD64 | 9.1.1.0    | Supervisor - vcf-cli.zip                                               |
# VCF Consumption CLI Plugins | Windows AMD64 | 9.1.1.0300 | VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip |
#-----------------------------+---------------+------------+------------------------------------------------------------------------+
#
# Download VCF CLI (Windows AMD64), kubectl, and vSphere Plugin (Windows AMD64) from the Supervisor. Supervisor Download URLs:
# https://$SUPERVISOR_API_ENDPOINT
#
# Download VCF Consumption CLI Plugins from Broadcom support. Broadcom Download URL:
# https://support.broadcom.com/group/ecx/productfiles?displayGroup=VMware%20Cloud%20Foundation%209&release=9.1.1.0&os=&servicePk=545627&language=EN&groupId=545621
#
# Broadcom Download Path:
# My Downloads -> VMware Cloud Foundation -> VMware Cloud Foundation 9.1.1.0
#----------------------------------------------------------------------------------------------------------------------------------+

$ErrorActionPreference = 'Stop'

$SUPERVISOR_API_ENDPOINT = "10.55.16.4"
$WORK_DIR = "$HOME\vcf-cli-install"
$INSTALL_DIR = "$env:LOCALAPPDATA\Programs\vcf"
$VCF_CLI_DOWNLOAD_URL = 'vcf-cli/v9.1.1.0/25662425/windows/amd64/vcf-cli.zip'
$KUBECTL_DOWNLOAD_URL = 'plugin/windows-amd64/vsphere-plugin.zip'
$VCF_CLI_PLUGIN_DOWNLOAD_FILE = "$env:USERPROFILE\Downloads\VCF-Consumption-CLI-PluginBundle-Windows_AMD64-9.1.1.0300.25882127.zip"

# Require the local plugin bundle before changing the installation.
if (-not (Test-Path -LiteralPath $VCF_CLI_PLUGIN_DOWNLOAD_FILE -PathType Leaf)) {
    throw "Plugin bundle not found: $VCF_CLI_PLUGIN_DOWNLOAD_FILE"
}

# Remove staging files left by a previous installation attempt.
if (Test-Path -LiteralPath $WORK_DIR) { Remove-Item -LiteralPath $WORK_DIR -Recurse -Force }

# Create separate staging directories for the CLI and plugin bundle.
New-Item -ItemType Directory -Path "$WORK_DIR\vcf-cli", "$WORK_DIR\vcf-plugins" -Force | Out-Null

# Create the kubectl extraction directory.
New-Item -ItemType Directory -Path "$WORK_DIR\vsphere-plugin" -Force | Out-Null

# Download the Supervisor packages, skipping certificate checks for the lab.
Invoke-WebRequest -Uri "https://$SUPERVISOR_API_ENDPOINT/wcp/$VCF_CLI_DOWNLOAD_URL" -SkipCertificateCheck -OutFile "$WORK_DIR\vcf-cli\vcf-cli.zip"
Invoke-WebRequest -Uri "https://$SUPERVISOR_API_ENDPOINT/wcp/$KUBECTL_DOWNLOAD_URL" -SkipCertificateCheck -OutFile "$WORK_DIR\vsphere-plugin.zip"

# Extract all packages before resetting the existing VCF configuration.
Expand-Archive -LiteralPath "$WORK_DIR\vcf-cli\vcf-cli.zip" -DestinationPath "$WORK_DIR\vcf-cli" -Force
Expand-Archive -LiteralPath "$WORK_DIR\vsphere-plugin.zip" -DestinationPath "$WORK_DIR\vsphere-plugin" -Force
Expand-Archive -LiteralPath $VCF_CLI_PLUGIN_DOWNLOAD_FILE -DestinationPath "$WORK_DIR\vcf-plugins" -Force

# Remove old VCF CLI configuration, plugin sources, caches and telemetry.
@(
    "$env:USERPROFILE\.cache\vcf"
    "$env:USERPROFILE\.config\vcf"
    "$env:USERPROFILE\.config\vcf-cli-telemetry"
    "$env:USERPROFILE\.local\share\vcf-cli"
    "$env:USERPROFILE\.local\vcf"
    "$env:USERPROFILE\.local\vcf-cli-telemetry"
) | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Recurse -Force
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null

# Install VCF CLI for Windows AMD64.
Copy-Item -LiteralPath "$WORK_DIR\vcf-cli\vcf-cli-windows_amd64.exe" -Destination "$INSTALL_DIR\vcf.exe" -Force
& "$INSTALL_DIR\vcf.exe" version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Install kubectl from the Windows AMD64 vSphere plugin package.
Copy-Item -LiteralPath "$WORK_DIR\vsphere-plugin\bin\kubectl.exe" -Destination "$INSTALL_DIR\kubectl.exe" -Force
& "$INSTALL_DIR\kubectl.exe" version --client=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Make the tools available now and in future terminals.
$env:Path = "$INSTALL_DIR;$env:Path"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $INSTALL_DIR) {
    [Environment]::SetEnvironmentVariable('Path', "$INSTALL_DIR;$userPath", 'User')
}

# Install the local Windows plugins.
& "$INSTALL_DIR\vcf.exe" plugin install all --local-source "$WORK_DIR\vcf-plugins"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$INSTALL_DIR\vcf.exe" plugin list
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Preserve the PowerShell profile and add the kubectl alias once.
New-Item -ItemType Directory -Path (Split-Path -Parent $PROFILE) -Force | Out-Null
$aliasLine = 'Set-Alias -Name k -Value kubectl'
if (-not (Test-Path -LiteralPath $PROFILE) -or
    -not (Select-String -LiteralPath $PROFILE -Pattern $aliasLine -SimpleMatch -Quiet)) {
    Add-Content -LiteralPath $PROFILE -Value "`n$aliasLine"
}

# Remove downloaded and extracted installation files.
Remove-Item -LiteralPath $WORK_DIR -Recurse -Force
Write-Host "Installed VCF CLI and kubectl in $INSTALL_DIR."
Write-Host 'Open a new terminal to use the updated user PATH.'
