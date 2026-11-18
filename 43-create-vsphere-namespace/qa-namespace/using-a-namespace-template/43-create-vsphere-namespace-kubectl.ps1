#Requires -Version 7.0
#-------------+--------------------------------------------------------------------------------------+
# Script Name | 43-create-vsphere-namespace-kubectl.ps1                                              |
# Updated     | 2026-11-15                                                                           |
# Version     | 1.2                                                                                  |
# VCF Version | 9.1.1.0-545627-2026-09                                                               |
# Description | Generate and create one self-service namespace using the active Supervisor template. |
#-------------+--------------------------------------------------------------------------------------+

#-------------+--------------------------------------------------------------------------------------+
# Requirement | Details                                                                              |
#-------------+--------------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.0+.                                                                     |
# Tools       | VCF CLI and kubectl in PATH.                                                         |
# Inputs      | Review the Supervisor context and namespace name in this script.                     |
# Access      | Reachable Supervisor API and an authenticated Supervisor context.                    |
# Permissions | Permission to use the active namespace template.                                     |
# Local files | Write access to deployment-files in the current working directory.                   |
# Config      | Access to the VCF configuration and kubeconfig for context refresh and selection.    |
#-------------+--------------------------------------------------------------------------------------+

$SUPERVISOR_CONTEXT = 'supervisor'
$NAMESPACE_NAME = 'qa-namespace'
$DEPLOYMENT_FILES = 'deployment-files'

# Create the deployment files directory.
New-Item -ItemType Directory -Path $DEPLOYMENT_FILES -Force | Out-Null

# Refresh Supervisor authentication without displaying output.
vcf context refresh $SUPERVISOR_CONTEXT *> $null

# Activate the Supervisor context.
vcf context use $SUPERVISOR_CONTEXT

# Generate namespace YAML using settings inherited from the active template.
kubectl create namespace $NAMESPACE_NAME --dry-run=client -o yaml | Set-Content -Path "$DEPLOYMENT_FILES/create-namespace-$NAMESPACE_NAME.yaml" -Encoding utf8

# Create the self-service namespace and report acceptance only when kubectl succeeds.
kubectl create -f "$DEPLOYMENT_FILES/create-namespace-$NAMESPACE_NAME.yaml" && Write-Output "Namespace creation request accepted: $NAMESPACE_NAME"
