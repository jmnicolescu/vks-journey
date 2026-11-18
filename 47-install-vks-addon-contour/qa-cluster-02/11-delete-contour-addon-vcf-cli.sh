#!/bin/bash
#-------------+-----------------------------------------------------------------+
# Script Name | 11-delete-contour-addon-vcf-cli.sh                              |
# Updated     | 2026-11-18                                                      |
# Version     | 1.12                                                            |
# VCF Version | 9.1.1.0-545627-2026-09                                          |
# Description | Delete the contour add-on, Gateway and GatewayClass from DEV.   |
#-------------+-----------------------------------------------------------------+

#-------------+-----------------------------------------------------------------+
# Requirement | Details                                                         |
#-------------+-----------------------------------------------------------------+
# Tools       | VCF CLI 9.1.1 and kubectl in PATH.                              |
# Access      | Authenticated Supervisor and workload contexts; API access.     |
# Inputs      | Set the Supervisor context, namespace and target cluster.       |
# Permissions | Delete contour, AddonConfig, Gateway and GatewayClass.         |
# Impact      | Removes contour, Envoy LoadBalancer, Gateway and GatewayClass.  |
# Behavior    | Changes active context; command failures do not stop execution. |
# Completion  | Waits for ClusterAddon and AddonConfig deletion.                |
#-------------+-----------------------------------------------------------------+
# set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02
GATEWAY_NAME=contour-gateway
READY_TIMEOUT=10m

echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}
# kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}


echo "Delete the contour add-on from the target VKS cluster."
vcf addon install delete contour \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    --yes

echo "Wait for the contour ClusterAddon to be deleted."
kubectl wait clusteraddon/${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained Contour AddonConfig and wait for cleanup."
# Delete the retained configuration and wait for its finalizers to finish.
kubectl delete addonconfig ${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the Contour deletion wait."
vcf addon install list \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE}

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
# vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete the Gateway if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n tanzu-system-ingress --ignore-not-found

echo "Delete the GatewayClass."
kubectl delete gatewayclass contour --ignore-not-found
