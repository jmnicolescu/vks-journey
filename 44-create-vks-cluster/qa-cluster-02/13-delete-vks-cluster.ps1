#Requires -Version 7.0
#-------------+---------------------------------------------------------------+
# Script Name | 13-delete-vks-cluster.ps1                                     |
# Updated     | 2026-11-15                                                    |
# Version     | 1.10                                                          |
# VCF Version | 9.1.1.0-545627-2026-09                                        |
# Description | Delete the configured VKS Cluster and wait for removal.       |
#-------------+---------------------------------------------------------------+

#-------------+---------------------------------------------------------------+
# Requirement | Details                                                       |
#-------------+---------------------------------------------------------------+
# Runtime     | PowerShell 7.                                                 |
# Tools       | VCF CLI, kubectl available in PATH.                           |
# Access      | Supervisor API connectivity and required cluster permissions. |
# Context     | Existing Supervisor context.                                  |
#-------------+---------------------------------------------------------------+

$ErrorActionPreference = 'Stop'

$CONTEXT_NAME = 'supervisor'
$REQUEST_TIMEOUT = 30
$WAIT_TIMEOUT = 1800
$CLUSTER01_NAMESPACE = 'qa-namespace'
$CLUSTER01_NAME = 'qa-cluster-02'

Write-Host "Refreshing Supervisor authentication..."
vcf context refresh $CONTEXT_NAME *> $null

# ------------------------------------------------------------------------------------------------------
# Use either the VCF or the kubectl context command below. Select the Supervisor context.
# vcf context use $CONTEXT_NAME
# vcf cluster delete $CLUSTER01_NAME -n $CLUSTER01_NAMESPACE --yes
# ------------------------------------------------------------------------------------------------------

Write-Host "Selecting Supervisor context $CONTEXT_NAME with kubectl..."
kubectl config use-context $CONTEXT_NAME

Write-Host "Submitting the deletion request for Cluster $CLUSTER01_NAME using kubectl..."
kubectl --context=$CONTEXT_NAME --request-timeout="$($REQUEST_TIMEOUT)s" -n $CLUSTER01_NAMESPACE delete cluster $CLUSTER01_NAME --wait=false

Write-Host "Waiting for Cluster $CLUSTER01_NAME to be removed..."
kubectl --context=$CONTEXT_NAME --request-timeout="$($REQUEST_TIMEOUT)s" -n $CLUSTER01_NAMESPACE wait cluster/$CLUSTER01_NAME --for=delete --timeout="$($WAIT_TIMEOUT)s"

Write-Host "Review the deletion result above for Cluster $CLUSTER01_NAME in namespace $CLUSTER01_NAMESPACE."
