#!/bin/bash
#----------------+------------------------------------------------------------------+
# Script Name    | 04-delete-assembly-webapp-gateway.sh                             |
# Updated        | 2026-11-17                                                       |
# Version        | 1.6                                                              |
# VCF Version    | 9.1.1                                                            |
# Description    | Delete the Assembly namespace and all resources in it.           |
#----------------+------------------------------------------------------------------+

#----------------+------------------------------------------------------------------+
# Requirement    | Details                                                          |
#----------------+------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                          |
# Tools          | VCF CLI and kubectl in PATH.                                     |
# Authentication | Existing VCF context with refreshable credentials.               |
# Access         | Workload cluster API connectivity.                               |
# Permissions    | Delete the application namespace and its resources.              |
# Configuration  | Set the target cluster and application namespace.                |
# Effect         | Deletes all app namespace resources; retains shared Gateway/TLS. |
#----------------+------------------------------------------------------------------+
set -e

# Editable lab inputs: set these names for the target environment.
CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-istio

GATEWAY_NAME=istio-assembly-gateway
GATEWAY_NAMESPACE=istio-gateway

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete the application HTTPRoutes before removing their backends."
kubectl delete httproutes --all -n ${NAMESPACE} --ignore-not-found --wait=true

echo "Delete the application workloads and services."
kubectl delete deployments,services,replicasets,pods --all -n ${NAMESPACE} \
    --ignore-not-found --wait=true

echo "Delete the application configuration, Secrets and service accounts."
kubectl delete configmaps,secrets,serviceaccounts --all -n ${NAMESPACE} \
    --ignore-not-found --wait=true

echo "Delete the namespace after its application objects have been removed."
kubectl delete namespace ${NAMESPACE} --ignore-not-found --wait=true

echo "Delete the Gateway ${GATEWAY_NAME} if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} --ignore-not-found

echo "Report completion; the shared Gateway and its TLS Secret remain configured."
echo "Namespace ${NAMESPACE} deleted. Shared Contour Gateway and TLS Secret retained."

