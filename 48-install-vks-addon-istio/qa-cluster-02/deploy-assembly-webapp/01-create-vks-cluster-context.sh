#!/usr/bin/env bash
#----------------+--------------------------------------------------------------------+
# Script Name    | 01-create-vks-cluster-context.sh                                   |
# Updated        | 2026-11-15                                                         |
# Version        | 1.10                                                               |
# VCF Version    | 9.1.1.0-545627-2026-09                                             |
# Description    | Create or recreate and activate the local VCF CLI cluster context. |
#----------------+--------------------------------------------------------------------+

#----------------+--------------------------------------------------------------------+
# Requirement    | Details                                                            |
#----------------+--------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                            |
# Tools          | VCF CLI, kubectl and OpenSSL available in PATH.                    |
# Access         | Supervisor and workload cluster API connectivity.                  |
# Authentication | vCenter SSO credentials with access to the target VKS cluster.     |
# Permissions    | Read cluster nodes; write local VCF context and kubeconfig files.  |
# Configuration  | Set the Supervisor endpoint, namespace and cluster name.           |
# TLS            | Retrieve the Supervisor certificate and use it for verification.   |
# Files          | Write access to the temporary Supervisor certificate file.         |
# Effect         | Recreates the local VCF context and selects the workload context.  |
#----------------+--------------------------------------------------------------------+

# ------------------------------------------------------------------------------------------------------
# SECURITY WARNING:
# The VCF_CLI_VSPHERE_PASSWORD variable contains a plaintext vCenter SSO password.
# Hardcoding credentials is NOT recommended for production environments.
# Never commit scripts containing passwords to Git repositories or share them publicly.
# Prefer secure credential management or interactive authentication.
# If exposed, rotate the password immediately.
# ------------------------------------------------------------------------------------------------------
set -eo pipefail

export VCF_CLI_VSPHERE_USERNAME='labadministrator@vsphere.local'
export VCF_CLI_VSPHERE_PASSWORD='VMwar3!!VMwar3!!'
SUPERVISOR_API_ENDPOINT=10.55.16.4
CERTIFICATE_FILE=/tmp/SUPERVISOR.crt
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02

echo "Checking that vcf, kubectl and openssl are available..."
for cmd in vcf kubectl openssl; do
  if ! command -v ${cmd} >/dev/null 2>&1; then
    echo "ERROR: ${cmd} is not installed or is not available in the system PATH." >&2
    echo "Please install ${cmd} and ensure it is accessible before proceeding." >&2
    exit 1
  fi
done

echo "Removing the previous Supervisor certificate file..."
rm -f ${CERTIFICATE_FILE}

echo "Retrieving the Supervisor API certificate..."
openssl s_client -connect ${SUPERVISOR_API_ENDPOINT}:443 -showcerts </dev/null 2>/dev/null  | openssl x509 -outform PEM > ${CERTIFICATE_FILE}

echo "Deleting the old context if it exists..."
vcf context delete ${CLUSTER_NAME} -y || true

# Not used because --insecure-skip-tls-verify disables verification of the Supervisor TLS certificate.
# vcf context create ${CLUSTER_NAME} \
#     --endpoint ${SUPERVISOR_API_ENDPOINT} \
#     --username ${VCF_CLI_VSPHERE_USERNAME} \
#     --workload-cluster-namespace ${CLUSTER_NAMESPACE} \
#     --workload-cluster-name ${CLUSTER_NAME} \
#     --insecure-skip-tls-verify \
#     --type k8s \
#     --auth-type basic

echo "Creating VKS workload context ${CLUSTER_NAME} using the saved Supervisor TLS certificate..."
vcf context create ${CLUSTER_NAME} \
    --endpoint ${SUPERVISOR_API_ENDPOINT} \
    --username ${VCF_CLI_VSPHERE_USERNAME} \
    --workload-cluster-namespace ${CLUSTER_NAMESPACE} \
    --workload-cluster-name ${CLUSTER_NAME} \
    --ca-certificate ${CERTIFICATE_FILE} \
    --type k8s \
    --auth-type basic


# ------------------------------------------------------------------------------------------------------
# Use either the VCF or the kubectl context command below.
# vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}
# vcf context list
# ------------------------------------------------------------------------------------------------------

echo "Activating VKS context: ${CLUSTER_NAME}:${CLUSTER_NAME}"
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Display available contexts."
kubectl config get-contexts

echo "Verifying Kubernetes cluster connectivity..."
kubectl get nodes

echo "SUCCESS: ${CLUSTER_NAME}:${CLUSTER_NAME} context configured successfully."

