#Requires -Version 7.0
#-------------+-----------------------------------------------------------------------------------+
# Script Name | 44-remove-vsphere-namespace-kubectl.ps1                                           |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.2                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Delete one self-service namespace owned by the authenticated user using kubectl.  |
#-------------+-----------------------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------------------+
# Requirement | Details                                                                           |
#-------------+-----------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.0+.                                                                  |
# Tools       | VCF CLI and kubectl in PATH.                                                      |
# Inputs      | Review the Supervisor context and namespace name in this script.                  |
# Access      | Reachable Supervisor API and an authenticated Supervisor context.                 |
# Permissions | Ownership of the self-service namespace being deleted.                            |
# Config      | Access to the VCF configuration and kubeconfig for context refresh and selection. |
# Effect      | Deletes the selected namespace and its workloads without a confirmation prompt.   |
#-------------+-----------------------------------------------------------------------------------+

$SUPERVISOR_CONTEXT = 'supervisor'
$NAMESPACE_NAME = 'qa-namespace'

# Refresh Supervisor authentication without displaying output.
vcf context refresh $SUPERVISOR_CONTEXT *> $null

# Select the Supervisor context.
kubectl config use-context $SUPERVISOR_CONTEXT

# Delete the owned self-service namespace and report acceptance only when kubectl succeeds.
kubectl delete namespace $NAMESPACE_NAME && Write-Output "Namespace deletion request accepted: $NAMESPACE_NAME"
