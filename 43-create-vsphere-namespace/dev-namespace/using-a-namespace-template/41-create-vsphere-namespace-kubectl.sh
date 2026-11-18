#!/usr/bin/env bash
#-------------+--------------------------------------------------------------------------------------+
# Script Name | 41-create-vsphere-namespace-kubectl.sh                                               |
# Updated     | 2026-11-15                                                                           |
# Version     | 1.6                                                                                  |
# VCF Version | 9.1.1.0-545627-2026-09                                                               |
# Description | Generate and create one self-service namespace using the active Supervisor template. |
#-------------+--------------------------------------------------------------------------------------+

#-------------+--------------------------------------------------------------------------------------+
# Requirement | Details                                                                              |
#-------------+--------------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                         |
# Tools       | VCF CLI, kubectl and mkdir in PATH.                                                  |
# Inputs      | Review the Supervisor context and namespace name in this script.                     |
# Access      | Reachable Supervisor API and an authenticated Supervisor context.                    |
# Permissions | Permission to use the active namespace template.                                     |
# Local files | Write access to deployment-files in the current working directory.                   |
# Config      | Access to the VCF configuration and kubeconfig for context refresh and selection.    |
#-------------+--------------------------------------------------------------------------------------+

# Stop when a command fails.
# set -e

SUPERVISOR_CONTEXT=supervisor
NAMESPACE_NAME=dev-namespace

# Resolve the directory containing this script.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

# Create the deployment files directory.
mkdir -p ${DEPLOYMENT_FILES}

# Select the Supervisor context. Refresh authentication (if needed).
vcf context refresh ${SUPERVISOR_CONTEXT} >/dev/null 2>&1
vcf context use ${SUPERVISOR_CONTEXT}

# Select the Supervisor context.
# kubectl config use-context ${SUPERVISOR_CONTEXT}

# Generate namespace YAML; storage policy, quota and VM classes come from the active template.
kubectl create namespace ${NAMESPACE_NAME} --dry-run=client -o yaml > ${DEPLOYMENT_FILES}/create-namespace-${NAMESPACE_NAME}.yaml

# Create the self-service namespace from the YAML file.
kubectl create -f ${DEPLOYMENT_FILES}/create-namespace-${NAMESPACE_NAME}.yaml

# Report acceptance of the namespace creation request.
[ $? -eq 0 ] && echo "Namespace creation request accepted: ${NAMESPACE_NAME}"
