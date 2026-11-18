#!/bin/bash
#-------------+-------------------------------------------------------------------+
# Script Name | 21-delete-contour-addon-kubectl.sh                                |
# Updated     | 2026-11-18                                                        |
# Version     | 1.5                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                            |
# Description | Delete the contour add-on, Gateway and GatewayClass.              |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Tools       | Bash, kubectl, jq and standard shell utilities.                   |
# Access      | Existing authenticated kubeconfig contexts; no login refresh.     |
# Inputs      | Set the Supervisor context, namespace and target cluster.         |
# Permissions | Manage AddonConfigs, AddonInstalls and target workload resources. |
# Impact      | Removes contour, Envoy LoadBalancer, Gateway and GatewayClass.    |
# Behavior    | Changes active context; stops when a command fails.               |
# Completion  | Waits for ClusterAddon and AddonConfig deletion.                  |
#-------------+-------------------------------------------------------------------+
set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02
GATEWAY_NAME=contour-gateway
READY_TIMEOUT=10m

echo "Select the target Supervisor namespace."
kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Delete the contour add-on from the target VKS cluster."
kubectl delete addoninstall contour-${CLUSTER_NAME} \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found

echo "Wait for the contour ClusterAddon to be deleted."
kubectl wait clusteraddon/${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained Contour AddonConfig and wait for cleanup."
# Delete the retained configuration and wait for its finalizers to finish.
kubectl delete addonconfig ${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the Contour deletion wait."
kubectl get clusteraddons -n ${CLUSTER_NAMESPACE} \
    -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Delete the Gateway if it exists."
kubectl delete gateway ${GATEWAY_NAME} -n tanzu-system-ingress --ignore-not-found

echo "Delete the GatewayClass."
kubectl delete gatewayclass contour --ignore-not-found
