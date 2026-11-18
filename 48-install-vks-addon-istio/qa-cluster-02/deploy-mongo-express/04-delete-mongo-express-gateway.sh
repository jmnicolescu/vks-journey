#!/bin/bash
#----------------+----------------------------------------------------------------------+
# Script Name    | 04-delete-mongo-express-gateway.sh                                   |
# Updated        | 2026-11-17                                                           |
# Version        | 1.5                                                                  |
# VCF Version    | 9.1.1                                                                |
# Description    | Delete MongoDB/Mongo Express and the dedicated Gateway.              |
#----------------+----------------------------------------------------------------------+

#----------------+----------------------------------------------------------------------+
# Requirement    | Details                                                              |
#----------------+----------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                              |
# Tools          | VCF CLI and kubectl in PATH.                                         |
# Authentication | Existing VCF context with refreshable credentials.                   |
# Access         | Workload cluster API connectivity.                                   |
# Permissions    | Delete app namespace resources and dedicated Gateway.                |
# Configuration  | Set the target cluster and application namespace.                    |
# Effect         | Deletes namespace including PVCs and dedicated Gateway; retains TLS. |
#----------------+----------------------------------------------------------------------+
set -e

# Editable lab inputs: set these names for the target environment.
CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-mongodb-istio

GATEWAY_NAME=istio-mongo-express-gateway
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

echo "Delete the namespace and its remaining resources, including MongoDB PVCs."
kubectl delete namespace ${NAMESPACE} --ignore-not-found --wait=true

echo "Delete the Gateway ${GATEWAY_NAME} if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} --ignore-not-found

echo "Report completion; the shared Gateway and its TLS Secret remain configured."
echo "Namespace ${NAMESPACE} deleted. Dedicated Gateway ${GATEWAY_NAME} deleted. Shared Istio Gateway and TLS Secret retained."

