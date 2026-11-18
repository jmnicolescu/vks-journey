#!/bin/bash
#-------------+-------------------------------------------------------------------+
# Script Name | 03-delete-mongo-express-lb.sh                                     |
# Updated     | 2026-11-18                                                        |
# Version     | 1.7                                                               |
# VCF Version | 9.1.1                                                             |
# Description | Delete the MongoDB and Mongo Express namespace and its resources. |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Runtime     | Linux or macOS with Bash.                                         |
# Tools       | VCF CLI and kubectl in PATH.                                      |
# Access      | Authenticated VCF context and workload Kubernetes API access.     |
# Inputs      | Set the target cluster and application namespace.                 |
# Permissions | Delete the application namespace and its resources.               |
# Deletion    | Deletes namespace workloads, services, configuration and PVCs.    |
# Storage     | Backing volume removal follows the PV reclaim policy.             |
#-------------+-------------------------------------------------------------------+

echo "Stop when a command fails."
set -e

CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-mongodb-lb

echo "Refresh workload cluster authentication."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete workloads and services in the application namespace."
kubectl delete deployments,services,replicasets,pods --all -n ${NAMESPACE}

echo "Delete configuration, credentials, and service accounts in the application namespace."
kubectl delete configmaps,secrets,serviceaccounts --all -n ${NAMESPACE}

echo "Delete namespace PVCs; backing volume cleanup follows the PV reclaim policy."
kubectl delete pvc --all -n ${NAMESPACE}

echo "Delete the namespace after its resources have been removed."
kubectl delete namespace ${NAMESPACE}

echo "Namespace ${NAMESPACE} deleted."
