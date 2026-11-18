#!/bin/bash
#-------------+---------------------------------------------------------------------------+
# Script Name | 11-delete-istio-addon-vcf-cli.sh                                          |
# Updated     | 2026-11-18                                                                |
# Version     | 1.8                                                                       |
# VCF Version | 9.1.1.0-545627-2026-09                                                    |
# Description | Delete the Istio add-on, Gateway and GatewayClass from DEV.               |
#-------------+---------------------------------------------------------------------------+

#-------------+---------------------------------------------------------------------------+
# Requirement | Details                                                                   |
#-------------+---------------------------------------------------------------------------+
# Tools       | VCF CLI 9.1.1 and kubectl in PATH.                                        |
# Access      | Authenticated Supervisor and workload contexts; API access.               |
# Inputs      | Set the Supervisor context, namespace and target cluster.                 |
# Permissions | Delete Istio, AddonConfig and Gateway resources; watch status.            |
# Impact      | Removes Istio, its Gateway and GatewayClass; retains cert-manager.        |
# Behavior    | Changes active context; stops when a command fails.                       |
# Completion  | Waits for Istio ClusterAddon and AddonConfig deletion.                    |
#-------------+---------------------------------------------------------------------------+
# set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=dev-namespace
CLUSTER_NAME=dev-cluster-01
READY_TIMEOUT=10m

GATEWAY_NAME=istio-gateway
GATEWAY_NAMESPACE=istio-gateway

echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
# kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Delete the istio add-on from the target VKS cluster."
vcf addon install delete istio \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    --yes

echo "Wait for the istio ClusterAddon to be deleted; stop if the wait times out."
kubectl wait clusteraddon/${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained Istio AddonConfig and wait for cleanup."
kubectl delete addonconfig ${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the Istio deletion wait."
vcf addon install list \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE}

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete the Gateway ${GATEWAY_NAME} if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} --ignore-not-found

echo "Delete the GatewayClass."
kubectl delete gatewayclass istio,istio-remote --ignore-not-found

echo "Delete istio-gateway namespace after its application objects have been removed."
kubectl delete namespace ${GATEWAY_NAMESPACE} --ignore-not-found --wait=true