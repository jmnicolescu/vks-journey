#!/bin/bash
#-------------+-----------------------------------------------------------------+
# Script Name | 12-delete-cert-manager-addon-vcf-cli.sh                         |
# Updated     | 2026-11-18                                                      |
# Version     | 1.2                                                             |
# VCF Version | 9.1.1.0-545627-2026-09                                          |
# Description | Delete the cert-manager add-on from DEV.                        |
#-------------+-----------------------------------------------------------------+

#-------------+-----------------------------------------------------------------+
# Requirement | Details                                                         |
#-------------+-----------------------------------------------------------------+
# Tools       | VCF CLI 9.1.1 and kubectl in PATH.                              |
# Access      | Authenticated Supervisor context; API access.                   |
# Inputs      | Set the Supervisor context, namespace and target cluster.       |
# Permissions | Delete cert-manager and AddonConfig; watch ClusterAddons.       |
# Impact      | Removes cert-manager from the target cluster.                   |
# Behavior    | Changes active context; command failures do not stop execution. |
# Completion  | Waits for ClusterAddon and AddonConfig deletion.                |
#-------------+-----------------------------------------------------------------+
# set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02
READY_TIMEOUT=10m

echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}
# kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Delete the cert-manager add-on from the target VKS cluster."
vcf addon install delete cert-manager \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    --yes

echo "Wait for the cert-manager ClusterAddon to be deleted."
kubectl wait clusteraddon/${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained cert-manager AddonConfig and wait for cleanup."
# Delete the retained configuration and wait for its finalizers to finish.
kubectl delete addonconfig ${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the cert-manager deletion wait."
vcf addon install list \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE}

