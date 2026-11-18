#!/usr/bin/env bash
#-------------+--------------------------------------------------------------------+
# Script Name | 11-install-vcf-linux-amd64.sh                                      |
# Updated     | 2026-11-15                                                         |
# Version     | 1.8                                                                |
# VCF Version | 9.1.1.0-545627-2026-09                                             |
# Description | Install VCF CLI, kubectl and plugins for Linux AMD64               |
#             | from files already downloaded into ~/Downloads.                    |
#-------------+--------------------------------------------------------------------+

#-------------+--------------------------------------------------------------------+
# Requirement | Details                                                            |
#-------------+--------------------------------------------------------------------+
# Runtime     | Bash on Linux AMD64 (x86_64).                                      |
# Input       | Local Linux AMD64 CLI archive, plugin bundle and kubectl.          |
# Tools       | tar, sudo, install, mkdir and rm.                                  |
# Access      | sudo rights to install vcf and kubectl in /usr/local/bin.          |
# File checks | Exits if any input file is missing, before staging or cleanup.     |
# Cleanup     | Resets VCF contexts, configuration, plugins, caches and telemetry. |
# Downloads   | Original downloads retained; ~/vcf-cli-install staging removed.    |
#-------------+--------------------------------------------------------------------+

#-----------------------------+--------------+------------+-------------------------------------------------------------------------+
# Component                   | Architecture | Version    | Download URL / Filename                                                 |
#-----------------------------+--------------+------------+-------------------------------------------------------------------------+
# kubectl                     | Linux AMD64  | v1.33.6    | https://dl.k8s.io/release/v1.33.6/bin/linux/amd64/kubectl               |
# VCF Consumption CLI         | Linux AMD64  | 9.1.1.0100 | VCF-Consumption-CLI-Linux_AMD64-9.1.1.0100.25746586.tar.gz              |
# VCF Consumption CLI Plugins | Linux AMD64  | 9.1.1.0100 | VCF-Consumption-CLI-PluginBundle-Linux_AMD64-9.1.1.0100.25793136.tar.gz |
#-----------------------------+--------------+------------+-------------------------------------------------------------------------+
#
# Download VCF Consumption CLI and VCF Consumption CLI Plugins from Broadcom support. Broadcom Download URL:
# https://support.broadcom.com/group/ecx/productfiles?displayGroup=VMware%20Cloud%20Foundation%209&release=9.1.1.0&os=&servicePk=545627&language=EN&groupId=545621
#
# Download Path:
# support.broadcom.com -> My Downloads -> VMware Cloud Foundation -> VMware Cloud Foundation 9.1.1.0
#-----------------------------+--------------+------------+-------------------------------------------------------------------------+

# Stop when a command fails or an undefined variable is used, including pipelines.
set -euo pipefail

# Restrict permissions on newly created installation files.
umask 077

DOWNLOAD_DIR=${HOME}/Downloads
WORK_DIR=${HOME}/vcf-cli-install

VCF_CLI_DOWNLOAD_FILE=${DOWNLOAD_DIR}/VCF-Consumption-CLI-Linux_AMD64-9.1.1.0100.25746586.tar.gz
KUBECTL_DOWNLOAD_FILE=${DOWNLOAD_DIR}/kubectl
VCF_CLI_PLUGIN_DOWNLOAD_FILE=${DOWNLOAD_DIR}/VCF-Consumption-CLI-PluginBundle-Linux_AMD64-9.1.1.0100.25793136.tar.gz

# Require the downloaded VCF CLI archive.
[ -f ${VCF_CLI_DOWNLOAD_FILE} ] || { echo "File not found: ${VCF_CLI_DOWNLOAD_FILE}" >&2; exit 1; }

# Require the downloaded kubectl binary.
[ -f ${KUBECTL_DOWNLOAD_FILE} ] || { echo "File not found: ${KUBECTL_DOWNLOAD_FILE}" >&2; exit 1; }

# Require the downloaded VCF plugin bundle.
[ -f ${VCF_CLI_PLUGIN_DOWNLOAD_FILE} ] || { echo "File not found: ${VCF_CLI_PLUGIN_DOWNLOAD_FILE}" >&2; exit 1; }

# Remove staging files left by a previous installation attempt.
rm -rf ${WORK_DIR}

# Create separate staging directories for the CLI and plugin bundle.
mkdir -p ${WORK_DIR}/vcf-cli ${WORK_DIR}/vcf-plugins

# Extract the already downloaded VCF CLI archive.
tar -xzf ${VCF_CLI_DOWNLOAD_FILE} -C ${WORK_DIR}/vcf-cli

# Extract the already downloaded plugin bundle to its local source directory.
tar -xzf ${VCF_CLI_PLUGIN_DOWNLOAD_FILE} -C ${WORK_DIR}/vcf-plugins

# Stage the already downloaded AMD64 kubectl before resetting VCF configuration.
install -m 755 ${KUBECTL_DOWNLOAD_FILE} ${WORK_DIR}/kubectl

# Announce the reset of existing VCF settings and saved contexts.
echo "Cleaning up local VCF CLI configuration and saved contexts..."

# Remove existing VCF configuration, plugin sources, caches and telemetry.
rm -rf ${HOME}/.cache/vcf ${HOME}/.config/vcf ${HOME}/.config/vcf-cli-telemetry \
    ${HOME}/.local/share/vcf-cli ${HOME}/.local/vcf ${HOME}/.local/vcf-cli-telemetry

# Announce the VCF CLI installation.
echo "Installing VCF CLI..."

# Create the destination directory for the utilities.
sudo mkdir -p /usr/local/bin

# Install the extracted Linux AMD64 VCF CLI binary.
sudo install -m 755 ${WORK_DIR}/vcf-cli/vcf-cli-linux_amd64 /usr/local/bin/vcf

# Display the installed VCF CLI version.
/usr/local/bin/vcf version

# Announce the kubectl installation.
echo "Installing kubectl..."

# Install the staged Linux AMD64 kubectl binary.
sudo install -m 755 ${WORK_DIR}/kubectl /usr/local/bin/kubectl

# Display the installed kubectl client version.
/usr/local/bin/kubectl version --client=true

# Announce the local VCF plugin installation.
echo "Installing VCF plugins from the local bundle..."

# Install all plugins from the extracted local bundle.
/usr/local/bin/vcf plugin install all --local-source ${WORK_DIR}/vcf-plugins

# List the installed VCF plugins.
/usr/local/bin/vcf plugin list

# Optionally disable automatic plugin-source discovery.
# /usr/local/bin/vcf config set features.global.disable-plugin-source-discovery true

# Remove only staging files, preserving the original downloads.
rm -rf ${WORK_DIR}
