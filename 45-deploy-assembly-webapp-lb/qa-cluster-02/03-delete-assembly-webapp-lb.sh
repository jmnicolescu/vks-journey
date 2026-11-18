#!/bin/bash
#----------------+---------------------------------------------------------------+
# Script Name    | 03-delete-assembly-webapp-lb.sh                               |
# Updated        | 2026-11-18                                                    |
# Version        | 1.5                                                           |
# VCF Version    | 9.1.1                                                         |
# Description    | Delete the Assembly WebApp namespace and all resources in it. |
#----------------+---------------------------------------------------------------+

#----------------+---------------------------------------------------------------+
# Requirement    | Details                                                       |
#----------------+---------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                       |
# Tools          | VCF CLI and kubectl available in PATH.                        |
# Authentication | Existing VCF context with credentials that can be refreshed.  |
# Access         | Workload cluster API connectivity.                            |
# Permissions    | Manage the application namespace and its resources.           |
# Configuration  | Set the target cluster name and application namespace.        |
# Effect         | Deletes the application namespace and all resources in it.    |
#----------------+---------------------------------------------------------------+

echo "Stop when a command fails."
set -e

CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-lb

echo "Refresh workload cluster authentication."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete workloads and services in the application namespace."
kubectl delete deployments,services,replicasets,pods --all -n ${NAMESPACE}

echo "Delete configuration, credentials, and service accounts in the application namespace."
kubectl delete configmaps,secrets,serviceaccounts --all -n ${NAMESPACE}

echo "Delete the namespace after its resources have been removed."
kubectl delete namespace ${NAMESPACE}

echo "Report successful namespace deletion."
echo "Namespace ${NAMESPACE} deleted."
