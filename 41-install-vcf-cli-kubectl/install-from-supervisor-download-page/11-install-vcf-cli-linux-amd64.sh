#!/usr/bin/env bash
#-------------+-----------------------------------------------------------------------+
# Script Name | 11-install-vcf-cli-linux-amd64.sh                                     |
# Updated     | 2026-11-15                                                            |
# Version     | 1.3                                                                   |
# VCF Version | 9.1.1.0-545627-2026-09                                                |
# Description | Install VCF CLI, kubectl and local VCF plugins for Linux AMD64.       |
#-------------+-----------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------+
# Requirement | Details                                                               |
#-------------+-----------------------------------------------------------------------+
# Runtime     | Bash on Linux AMD64.                                                  |
# Endpoint    | Set SUPERVISOR_API_ENDPOINT directly in this script.                  |
# Access      | Supervisor HTTPS access and sudo rights to install in /usr/local/bin. |
# Input       | Local VCF plugin bundle matching the configured path and platform.    |
# Tools       | curl, tar, unzip, sudo, install, mkdir and rm.                        |
# Cleanup     | Removes existing VCF configuration, caches and telemetry directories. |
#-------------+-----------------------------------------------------------------------+

#--------------------------------------------------------------------------------------------------------------------------------------+
# Component                   | Architecture | Version      | Download Source                                                          |
#-----------------------------+--------------+--------------+--------------------------------------------------------------------------+
# kubectl vSphere Plugin      | Linux AMD64  | Supervisor   | Supervisor - vsphere-plugin.zip                                          |
# VCF CLI                     | Linux AMD64  | 9.1.1.0      | Supervisor - vcf-cli.tar.gz                                              |
# VCF Consumption CLI Plugins | Linux AMD64  | 9.1.1.0100   | VCF-Consumption-CLI-PluginBundle-Linux_AMD64-9.1.1.0100.25793136.tar.gz  |
#-----------------------------+--------------+--------------+--------------------------------------------------------------------------+
#
# Download VCF CLI (Linux AMD64), kubectl, and vSphere Plugin (Linux AMD64) from the Supervisor. Supervisor Download URLs:
# https://${SUPERVISOR_API_ENDPOINT}
#
# Download VCF Consumption CLI Plugins from Broadcom support. Broadcom Download URL:
# https://support.broadcom.com/group/ecx/productfiles?displayGroup=VMware%20Cloud%20Foundation%209&release=9.1.1.0&os=&servicePk=545627&language=EN&groupId=545621
#
# Broadcom Download Path:
# My Downloads -> VMware Cloud Foundation -> VMware Cloud Foundation 9.1.1.0
#----------------------------------------------------------------------------------------------------------------------------------+

set -euo pipefail
umask 077

SUPERVISOR_API_ENDPOINT=10.55.16.4
WORK_DIR=${HOME}/vcf-cli-install

VCF_CLI_DOWNLOAD_URL='vcf-cli/v9.1.1.0/25662425/linux/amd64/vcf-cli.tar.gz'
KUBECTL_DOWNLOAD_URL='plugin/linux-amd64/vsphere-plugin.zip'
VCF_CLI_PLUGIN_DOWNLOAD_FILE=/tmp/VCF-Consumption-CLI-PluginBundle-Linux_AMD64-9.1.1.0100.25793136.tar.gz

command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }

# Require the downloaded plugin bundle before changing the local installation.
if [ ! -f "${VCF_CLI_PLUGIN_DOWNLOAD_FILE}" ]; then
  echo "Plugin bundle not found: ${VCF_CLI_PLUGIN_DOWNLOAD_FILE}" >&2
  exit 1
fi

# Remove old VCF CLI configuration, plugin sources, caches and telemetry.
echo "Cleaning up local VCF CLI directories..."
rm -rf ${HOME}/.cache/vcf ${HOME}/.config/vcf ${HOME}/.config/vcf-cli-telemetry \
  ${HOME}/.local/share/vcf-cli ${HOME}/.local/vcf ${HOME}/.local/vcf-cli-telemetry 

# Remove staging files left by a previous installation attempt.
rm -rf ${WORK_DIR}

# Create separate staging directories for the CLI and plugin bundle.
mkdir -p ${WORK_DIR}/vcf-cli ${WORK_DIR}/vcf-plugins

# Install VCF CLI for Linux AMD64.
echo "Installing VCF CLI..."
curl -kfSL https://${SUPERVISOR_API_ENDPOINT}/wcp/${VCF_CLI_DOWNLOAD_URL} -o ${WORK_DIR}/vcf-cli/vcf-cli.tar.gz
tar -xzf ${WORK_DIR}/vcf-cli/vcf-cli.tar.gz -C ${WORK_DIR}/vcf-cli
sudo mkdir -p /usr/local/bin
sudo install -m 755 ${WORK_DIR}/vcf-cli/vcf-cli-linux_amd64 /usr/local/bin/vcf
/usr/local/bin/vcf version

# Install kubectl from the supplied Linux AMD64 vSphere plugin package.
echo "Installing kubectl..."
curl -kfSL https://${SUPERVISOR_API_ENDPOINT}/wcp/${KUBECTL_DOWNLOAD_URL} -o ${WORK_DIR}/vsphere-plugin.zip
unzip -oq ${WORK_DIR}/vsphere-plugin.zip -d ${WORK_DIR}/vsphere-plugin
sudo install -m 755 ${WORK_DIR}/vsphere-plugin/bin/kubectl /usr/local/bin/kubectl
/usr/local/bin/kubectl version --client=true

# Extract and install cli plugins
tar -xvzf ${VCF_CLI_PLUGIN_DOWNLOAD_FILE} -C ${WORK_DIR}/vcf-plugins

# Install plugins and confirm
echo "Installing VCF plugins..."
/usr/local/bin/vcf plugin install all --local-source ${WORK_DIR}/vcf-plugins
/usr/local/bin/vcf plugin list

# Disable automatic plugin-source discovery.
# /usr/local/bin/vcf config set features.global.disable-plugin-source-discovery true

# Remove downloaded installation files.
rm -f ${WORK_DIR}/vsphere-plugin.zip
rm -rf ${WORK_DIR}/vcf-cli ${WORK_DIR}/vsphere-plugin ${WORK_DIR}/vcf-plugins

