#Requires -Version 7.0
#----------------+---------------------------------------------------------------+
# Script Name    | 13-delete-assembly-webapp-lb.ps1                              |
# Updated        | 2026-11-14                                                    |
# Version        | 1.4                                                           |
# VCF Version    | 9.1.1                                                         |
# Description    | Delete the Assembly WebApp namespace and all resources in it. |
#----------------+---------------------------------------------------------------+

#----------------+---------------------------------------------------------------+
# Requirement    | Details                                                       |
#----------------+---------------------------------------------------------------+
# Runtime        | PowerShell 7.0 or later.                                      |
# Tools          | VCF CLI and kubectl available in PATH.                        |
# Authentication | Existing VCF context with credentials that can be refreshed.  |
# Access         | Workload cluster API connectivity.                            |
# Permissions    | Manage the application namespace and its resources.           |
# Configuration  | Set the target cluster name and application namespace.        |
# Effect         | Deletes the application namespace and all resources in it.    |
#----------------+---------------------------------------------------------------+

# Stop when a PowerShell command fails; native commands below exit on failure.
$ErrorActionPreference = 'Stop'

$CLUSTER_NAME = 'qa-cluster-02'
$NAMESPACE = 'qa-assembly-lb'

# Refresh workload cluster authentication.
vcf context refresh $CLUSTER_NAME || $(exit $LASTEXITCODE)

# Select the workload Kubernetes context.
kubectl config use-context "$($CLUSTER_NAME):$CLUSTER_NAME" || $(exit $LASTEXITCODE)

# Delete the application workloads and services in the namespace.
kubectl delete --all deployments,services,replicasets,pods --namespace=$NAMESPACE || $(exit $LASTEXITCODE)

# Delete service accounts and secrets in the namespace.
kubectl delete --all serviceaccounts,secrets --namespace=$NAMESPACE || $(exit $LASTEXITCODE)

# Delete the namespace and all remaining resources in it.
kubectl delete namespace $NAMESPACE || $(exit $LASTEXITCODE)

# Report that the namespace was deleted.
Write-Host "Namespace $NAMESPACE deleted."
