#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 10-switch-to-wildcard-certificate.sh                                  |
# Updated        | 2026-11-18                                                            |
# Version        | 1.4                                                                   |
# VCF Version    | 9.1.1                                                                 |
# Description    | Configure the shared Contour Gateway with wildcard TLS.               |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                               |
# Tools          | VCF CLI, kubectl, jq and column in PATH.                              |
# Authentication | Existing VCF context with refreshable credentials.                    |
# Access         | Workload cluster API connectivity and Gateway API v1 CRDs.            |
# Permissions    | Replace the Gateway and manage its TLS Secret.                        |
# Configuration  | Set cluster, Gateway, wildcard hostname and certificate name.         |
# Infrastructure | Contour and the shared Gateway must already exist.                    |
# Files          | Matching .key and .cer.plusCA files in certificates/.                 |
# Output         | Gateway manifest in deployment-files beside this script.              |
# Effect         | Updates shared HTTP/HTTPS listeners and the wildcard Secret.          |
#----------------+-----------------------------------------------------------------------+

echo "Stop when a command or pipeline fails."
set -e -o pipefail

# Editable lab inputs: set these names for the target environment.
CLUSTER_NAME=qa-cluster-02
GATEWAY_NAME=contour-gateway
GATEWAY_CLASS_NAME=contour
GATEWAY_NAMESPACE=tanzu-system-ingress

WILDCARD_HOSTNAME='*.platformlab.vcf'
CERTIFICATE_NAME=wildcard.platformlab.vcf
TLS_SECRET_NAME=platformlab-wildcard-tls

echo "Resolve the script directory, including paths containing spaces."
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates
SERVER_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${CERTIFICATE_NAME}.key
SERVER_CERTIFICATE_CHAIN_PATH=${CERTIFICATES_DIR}/${CERTIFICATE_NAME}.cer.plusCA

echo "Create the deployment manifest directory."
mkdir -p "${DEPLOYMENT_FILES}"

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Create or update the wildcard TLS Secret without saving its private key to a file."
kubectl create secret tls ${TLS_SECRET_NAME} \
    --cert="${SERVER_CERTIFICATE_CHAIN_PATH}" \
    --key="${SERVER_PRIVATE_KEY_PATH}" \
    --namespace=${GATEWAY_NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Write the complete shared HTTP/HTTPS Gateway configuration."
cat << EOF > "${DEPLOYMENT_FILES}/${GATEWAY_NAME}-resource.yaml"
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: ${GATEWAY_CLASS_NAME}
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      hostname: "${WILDCARD_HOSTNAME}"
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: ${TLS_SECRET_NAME}
      allowedRoutes:
        namespaces:
          from: All
EOF

echo "Replace the existing Gateway configuration."
kubectl replace -f "${DEPLOYMENT_FILES}/${GATEWAY_NAME}-resource.yaml"

echo "Display the wildcard TLS Secret metadata."
kubectl get secret ${TLS_SECRET_NAME} -n ${GATEWAY_NAMESPACE}

echo "Display Gateway listeners and reconciliation conditions."
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o yaml

echo "Display the current Gateway configuration and listener conditions as a table."
echo
echo "Gateway listener summary: ${GATEWAY_NAMESPACE}/${GATEWAY_NAME}"

echo "Mark conditions from an older Gateway generation as pending reconciliation."
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o json | \
    jq -r '
        . as $gateway |
        def condition($conditions; $type):
            ([$conditions[]? | select(.type == $type)] | first) as $condition |
            if $condition == null then "Pending"
            elif $condition.observedGeneration != $gateway.metadata.generation then "Pending"
            else $condition.status end;
        (["LISTENER", "PROTOCOL", "PORT", "HOSTNAME", "CERTIFICATE_SECRET", "ACCEPTED", "PROGRAMMED", "RESOLVED_REFS"] | @tsv),
        (.spec.listeners[] as $listener |
            ([$gateway.status.listeners[]? | select(.name == $listener.name)] | first) as $status |
            [
                $listener.name,
                $listener.protocol,
                ($listener.port | tostring),
                ($listener.hostname // "All"),
                ([$listener.tls.certificateRefs[]? |
                    ((.namespace // $gateway.metadata.namespace) + "/" + .name)] |
                    if length == 0 then "-" else join(",") end),
                condition($status.conditions; "Accepted"),
                condition($status.conditions; "Programmed"),
                condition($status.conditions; "ResolvedRefs")
            ] | @tsv)
    ' | column -t -s $'\t'

echo "Explain the status snapshot without claiming that application traffic was tested."
echo "Pending means the controller has not reported a condition for the current Gateway generation."
echo "This table shows Gateway configuration and status; use script 91 for certificate details and HTTPRoute status."
