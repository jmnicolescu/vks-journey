#!/usr/bin/env bash
#-------------+---------------------------------------------------------------+
# Script Name | 03-delete-vks-cluster.sh                                      |
# Updated     | 2026-11-15                                                    |
# Version     | 1.14                                                          |
# VCF Version | 9.1.1.0-545627-2026-09                                        |
# Description | Delete the configured VKS Cluster and wait for removal.       |
#-------------+---------------------------------------------------------------+

#-------------+---------------------------------------------------------------+
# Requirement | Details                                                       |
#-------------+---------------------------------------------------------------+
# Runtime     | Bash on macOS or Linux.                                       |
# Tools       | VCF CLI, kubectl available in PATH.                           |
# Access      | Supervisor API connectivity and required cluster permissions. |
# Context     | Existing Supervisor context.                                  |
#-------------+---------------------------------------------------------------+

set -e

CONTEXT_NAME=supervisor
REQUEST_TIMEOUT=30
WAIT_TIMEOUT=1800
CLUSTER01_NAMESPACE=qa-namespace
CLUSTER01_NAME=qa-cluster-02

echo "Refreshing Supervisor authentication..."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

# ------------------------------------------------------------------------------------------------------
# Use either the VCF or the kubectl context command below. Select the Supervisor context.
# vcf context use ${CONTEXT_NAME}
# vcf cluster delete ${CLUSTER01_NAME} -n ${CLUSTER01_NAMESPACE} --yes
# ------------------------------------------------------------------------------------------------------

echo "Selecting Supervisor context ${CONTEXT_NAME} with kubectl..."
kubectl config use-context ${CONTEXT_NAME}

echo "Submitting the deletion request for Cluster ${CLUSTER01_NAME} using kubectl..."
kubectl --request-timeout=${REQUEST_TIMEOUT}s -n ${CLUSTER01_NAMESPACE} \
    delete cluster ${CLUSTER01_NAME} --wait=false

echo "Waiting for Cluster ${CLUSTER01_NAME} to be removed..."
kubectl --request-timeout=${REQUEST_TIMEOUT}s -n ${CLUSTER01_NAMESPACE} \
    wait cluster/${CLUSTER01_NAME} --for=delete --timeout=${WAIT_TIMEOUT}s

echo "Cluster ${CLUSTER01_NAME} is no longer present in namespace ${CLUSTER01_NAMESPACE}."
