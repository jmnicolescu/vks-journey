#!/usr/bin/env bash
#-------------+-----------------------------------------------------------------------------------+
# Script Name | 42-remove-vsphere-namespace-kubectl.sh                                            |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.6                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Delete one self-service namespace owned by the authenticated user using kubectl.  |
#-------------+-----------------------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------------------+
# Requirement | Details                                                                           |
#-------------+-----------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                      |
# Tools       | VCF CLI and kubectl in PATH.                                                      |
# Inputs      | Review the Supervisor context and namespace name in this script.                  |
# Access      | Reachable Supervisor API and an authenticated Supervisor context.                 |
# Permissions | Ownership of the self-service namespace being deleted.                            |
# Config      | Access to the VCF configuration and kubeconfig for context refresh and selection. |
# Effect      | Deletes the selected namespace and its workloads without a confirmation prompt.   |
#-------------+-----------------------------------------------------------------------------------+

# Stop when a command fails.
# set -e

SUPERVISOR_CONTEXT=supervisor
NAMESPACE_NAME=dev-namespace

# Refresh Supervisor authentication.
vcf context refresh ${SUPERVISOR_CONTEXT} >/dev/null 2>&1

# Select the Supervisor context.
kubectl config use-context ${SUPERVISOR_CONTEXT}

# Delete the owned self-service namespace and its namespaced workloads.
kubectl delete namespace ${NAMESPACE_NAME}

# Report acceptance of the namespace deletion request.
[ $? -eq 0 ] && echo "Namespace deletion request accepted: ${NAMESPACE_NAME}"
