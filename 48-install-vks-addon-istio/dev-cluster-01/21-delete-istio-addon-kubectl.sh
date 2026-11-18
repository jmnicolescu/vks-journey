#!/bin/bash
#-------------+-------------------------------------------------------------------------+
# Script Name | 21-delete-istio-addon-kubectl.sh                                        |
# Updated     | 2026-11-18                                                              |
# Version     | 1.2                                                                     |
# VCF Version | 9.1.1.0-545627-2026-09                                                  |
# Description | Delete Istio and its Gateway resources using kubectl.                   |
#-------------+-------------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------------+
# Requirement | Details                                                                 |
#-------------+-------------------------------------------------------------------------+
# Runtime     | Bash on macOS/Linux.                                                    |
# Tools       | VCF CLI 9.1.1, kubectl and standard shell utilities.                    |
# Access      | Authenticated Supervisor and workload kubeconfig contexts.              |
# Permissions | Delete AddonInstall, AddonConfig and Gateway resources.                 |
# Impact      | Removes the Gateway namespace and its TLS Secret; retains cert-manager. |
# Behavior    | Refreshes authentication; waits for ClusterAddon deletion.              |
#-------------+-------------------------------------------------------------------------+
set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=dev-namespace
CLUSTER_NAME=dev-cluster-01
READY_TIMEOUT=10m

GATEWAY_NAME=istio-gateway
GATEWAY_NAMESPACE=istio-gateway

echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Delete the istio add-on from the target VKS cluster."
kubectl delete addoninstall istio-${CLUSTER_NAME} -n ${CLUSTER_NAMESPACE} \
    --ignore-not-found --timeout=${READY_TIMEOUT}

echo "Wait for the istio ClusterAddon to be deleted; stop if the wait times out."
kubectl wait clusteraddon/${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained Istio AddonConfig and wait for cleanup."
kubectl delete addonconfig ${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the Istio deletion wait."
kubectl get clusteraddons -n ${CLUSTER_NAMESPACE} -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete the Gateway ${GATEWAY_NAME} if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} --ignore-not-found

echo "Delete the GatewayClass."
kubectl delete gatewayclass istio istio-remote --ignore-not-found

echo "Delete istio-gateway namespace after its application objects have been removed."
kubectl delete namespace ${GATEWAY_NAMESPACE} --ignore-not-found --wait=true
