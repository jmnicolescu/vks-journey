#Requires -Version 7.0
#-------------+-------------------------------------------------------------------+
# Script Name | 13-delete-mongo-express-lb.ps1                                    |
# Updated     | 2026-11-14                                                        |
# Version     | 1.2                                                               |
# VCF Version | 9.1.1                                                             |
# Description | Delete the MongoDB and Mongo Express namespace and its resources. |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Runtime     | PowerShell 7.0+ with compatible VCF CLI and kubectl binaries.     |
# Tools       | VCF CLI and kubectl in PATH.                                      |
# Access      | Authenticated VCF context and workload Kubernetes API access.     |
# Inputs      | Set the target cluster and application namespace.                 |
# Permissions | Delete the application namespace and its resources.               |
# Deletion    | Deletes namespace workloads, services, configuration and PVCs.    |
# Storage     | Backing volume removal follows the PV reclaim policy.             |
#-------------+-------------------------------------------------------------------+

# Stop when a PowerShell command fails; native commands below exit on failure.
$ErrorActionPreference = 'Stop'

$CLUSTER_NAME = 'qa-cluster-02'
$NAMESPACE = 'qa-mongodb-lb'

# Refresh workload cluster authentication.
vcf context refresh $CLUSTER_NAME || $(exit $LASTEXITCODE)

# Select the workload Kubernetes context.
kubectl config use-context "$($CLUSTER_NAME):$CLUSTER_NAME" || $(exit $LASTEXITCODE)

# Delete workloads and services in the application namespace.
kubectl delete 'deployments,services,replicasets,pods' --all -n $NAMESPACE || $(exit $LASTEXITCODE)

# Delete configuration, credentials, and service accounts in the application namespace.
kubectl delete 'configmaps,secrets,serviceaccounts' --all -n $NAMESPACE || $(exit $LASTEXITCODE)

# Delete namespace PVCs; backing volume cleanup follows the PV reclaim policy.
kubectl delete pvc --all -n $NAMESPACE || $(exit $LASTEXITCODE)

# Delete the namespace after its resources have been removed.
kubectl delete namespace $NAMESPACE || $(exit $LASTEXITCODE)

# Report successful namespace deletion.
Write-Host "Namespace $NAMESPACE deleted."
