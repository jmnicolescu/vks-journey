#!/usr/bin/env bash
#-------------+-----------------------------------------------------------------------------+
# Script Name | 02-create-vks-cluster.sh                                                    |
# Updated     | 2026-11-15                                                                  |
# Version     | 1.22                                                                        |
# VCF Version | 9.1.1.0-545627-2026-09                                                      |
# Description | Generate the VKS Cluster manifest, submit it and wait for availability.     |
#-------------+-----------------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------------+
# Requirement | Details                                                                     |
#-------------+-----------------------------------------------------------------------------+
# Runtime     | Bash on macOS or Linux.                                                     |
# Tools       | VCF CLI, kubectl available in PATH.                                         |
# Access      | Supervisor API connectivity and required cluster permissions.               |
# Context     | Existing Supervisor context.                                                |
# Files       | Write access to deployment-files beside this script.                        |
#-------------+-----------------------------------------------------------------------------+

set -e

CONTEXT_NAME=supervisor
REQUEST_TIMEOUT=30
WAIT_TIMEOUT=1800
CLUSTER01_NAMESPACE=qa-namespace
CLUSTER01_NAME=qa-cluster-02
CLUSTER01_MANIFEST=create-qa-cluster-02.yaml

# Locate the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

echo "Creating deployment files directory ${DEPLOYMENT_FILES}..."
mkdir -p ${DEPLOYMENT_FILES}

echo "Creating the cluster manifest with the configured topology and sizing..."
cat > ${DEPLOYMENT_FILES}/${CLUSTER01_MANIFEST} <<EOF
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${CLUSTER01_NAME}
  namespace: ${CLUSTER01_NAMESPACE}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 10.95.0.0/16
    services:
      cidrBlocks:
        - 10.96.0.0/12
    serviceDomain: cluster.local
  topology:
    classRef:
      name: builtin-generic-v3.7.0
      namespace: vmware-system-vks-public
    version: v1.35.6---vmware.2-vkr.3
    variables:
      - name: vmClass
        value: best-effort-medium
      - name: storageClass
        value: vsan-default-storage-policy
      - name: bootstrapAddons
        value:
          cniRef:
            name: antrea
            namespace: vmware-system-vks-public
      - name: kubernetes
        value:
          certificateRotation:
            enabled: true
            renewalDaysBeforeExpiry: 90
          security:
            podSecurityStandard:
              audit: restricted
              auditVersion: latest
              enforce: privileged
              enforceVersion: latest
              warn: privileged
              warnVersion: latest
    controlPlane:
      replicas: 3
      metadata:
        annotations:
          run.tanzu.vmware.com/resolve-os-image: os-name=photon
    workers:
      machineDeployments:
        - class: node-pool
          name: ${CLUSTER01_NAME}-np01
          replicas: 3
          metadata:
            annotations:
              run.tanzu.vmware.com/resolve-os-image: os-name=photon
          variables:
            overrides:
              - name: volumes
                value:
                  - name: vol-containerd
                    mountPath: /var/lib/containerd
                    storageClass: vsan-default-storage-policy
                    capacity: 30Gi
EOF

echo "Refreshing Supervisor authentication..."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

# ------------------------------------------------------------------------------------------------------
# Use either the VCF or the kubectl context command below. Select the Supervisor context.
# vcf context use ${CONTEXT_NAME}
# vcf cluster create -f ${DEPLOYMENT_FILES}/${CLUSTER01_MANIFEST} --yes
# ------------------------------------------------------------------------------------------------------

echo "Selecting Supervisor context ${CONTEXT_NAME} with kubectl..."
kubectl config use-context ${CONTEXT_NAME}

echo "Applying the manifest to create or update Cluster ${CLUSTER01_NAME}..."
kubectl apply -f ${DEPLOYMENT_FILES}/${CLUSTER01_MANIFEST}

echo "Waiting for Cluster ${CLUSTER01_NAME} to report availability..."
kubectl --request-timeout=${REQUEST_TIMEOUT}s -n ${CLUSTER01_NAMESPACE} \
    wait cluster/${CLUSTER01_NAME} --for=condition=Available=True --timeout=${WAIT_TIMEOUT}s

# Alternative: list the clusters visible to VCF.
# vcf cluster list -A

echo "Listing Cluster API clusters across all Supervisor namespaces..."
kubectl get clusters -A

# echo "Displaying the current state of Cluster ${CLUSTER01_NAME}..."
# kubectl -n ${CLUSTER01_NAMESPACE} get clusters ${CLUSTER01_NAME} -o yaml

echo "Cluster ${CLUSTER01_NAME} is available in namespace ${CLUSTER01_NAMESPACE}."
