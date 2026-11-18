#!/bin/bash
#-------------+-------------------------------------------------------------------+
# Script Name | 22-delete-cert-manager-addon-kubectl.sh                           |
# Updated     | 2026-11-18                                                        |
# Version     | 1.1                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                            |
# Description | Delete the cert-manager add-on.                                   |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Tools       | Bash, kubectl, jq and standard shell utilities.                   |
# Access      | Existing authenticated kubeconfig contexts; no login refresh.     |
# Inputs      | Set the Supervisor context, namespace and target cluster.         |
# Permissions | Manage AddonConfigs, AddonInstalls and target workload resources. |
# Impact      | Removes cert-manager from the target cluster.                     |
# Behavior    | Changes active context; stops when a command fails.               |
# Completion  | Waits for ClusterAddon and AddonConfig deletion.                  |
#-------------+-------------------------------------------------------------------+
set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02
READY_TIMEOUT=10m

echo "Select the target Supervisor namespace."
kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Delete the cert-manager add-on from the target VKS cluster."
kubectl delete addoninstall cert-manager-${CLUSTER_NAME} \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found

echo "Wait for the cert-manager ClusterAddon to be deleted."
kubectl wait clusteraddon/${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --for=delete --timeout=${READY_TIMEOUT}

echo "Delete any retained cert-manager AddonConfig and wait for cleanup."
# Delete the retained configuration and wait for its finalizers to finish.
kubectl delete addonconfig ${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found \
    --wait=true --timeout=${READY_TIMEOUT}

echo "Display remaining add-ons after the cert-manager deletion wait."
kubectl get clusteraddons -n ${CLUSTER_NAMESPACE} \
    -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}

