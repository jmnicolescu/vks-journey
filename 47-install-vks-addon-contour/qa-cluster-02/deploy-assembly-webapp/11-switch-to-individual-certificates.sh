#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 11-switch-to-individual-certificates.sh                               |
# Updated        | 2026-11-18                                                            |
# Version        | 1.6                                                                   |
# VCF Version    | 9.1.1                                                                 |
# Description    | Switch shared Contour HTTPS to individual app certificates.           |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                               |
# Tools          | VCF CLI, kubectl, jq and column in PATH.                              |
# Authentication | Existing VCF context with refreshable credentials.                    |
# Access         | Workload cluster API connectivity and Gateway API v1 CRDs.            |
# Permissions    | Replace the Gateway and manage its TLS Secrets.                       |
# Configuration  | Set cluster, Gateway, app FQDNs and TLS Secret names.                 |
# Infrastructure | Existing Contour Gateway and app routes bound to matching listeners.  |
# Files          | Matching <FQDN>.key and <FQDN>.cer.plusCA in certificates/.           |
# DNS            | App FQDNs must resolve to the shared Gateway address.                 |
# Output         | Gateway manifest in deployment-files; no private key copies.          |
# Effect         | Replaces Gateway configuration with individual TLS listeners.         |
# Retained       | HTTPRoutes, wildcard Secret, app workloads and Services.              |
#----------------+-----------------------------------------------------------------------+

echo "Stop when a command or pipeline fails."
set -e -o pipefail

# Editable lab inputs: set these names for the target environment.
CLUSTER_NAME=qa-cluster-02
GATEWAY_NAME=contour-gateway
GATEWAY_CLASS_NAME=contour
GATEWAY_NAMESPACE=tanzu-system-ingress

ASSEMBLY_FQDN=qa-assembly-contour.platformlab.vcf
ASSEMBLY_TLS_SECRET=assembly-tls

MONGO_FQDN=qa-mongo-express-contour.platformlab.vcf
MONGO_TLS_SECRET=mongo-express-tls

echo "Resolve the script directory, including paths containing spaces."
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates

echo "Create the deployment manifest directory."
mkdir -p "${DEPLOYMENT_FILES}"

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Create or update the ASSEMBLY TLS Secret without writing its private key to output files."
kubectl create secret tls ${ASSEMBLY_TLS_SECRET} \
    --cert="${CERTIFICATES_DIR}/${ASSEMBLY_FQDN}.cer.plusCA" \
    --key="${CERTIFICATES_DIR}/${ASSEMBLY_FQDN}.key" \
    --namespace=${GATEWAY_NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Create or update the MONGO TLS Secret without writing its private key to output files."
kubectl create secret tls ${MONGO_TLS_SECRET} \
    --cert="${CERTIFICATES_DIR}/${MONGO_FQDN}.cer.plusCA" \
    --key="${CERTIFICATES_DIR}/${MONGO_FQDN}.key" \
    --namespace=${GATEWAY_NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Write the complete Gateway configuration with HTTP and HTTPS for each application."
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
      hostname: "${ASSEMBLY_FQDN}"
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: http-mongo-express
      hostname: "${MONGO_FQDN}"
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      hostname: "${ASSEMBLY_FQDN}"
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: ${ASSEMBLY_TLS_SECRET}
      allowedRoutes:
        namespaces:
          from: All
    - name: https-mongo-express
      hostname: "${MONGO_FQDN}"
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: ${MONGO_TLS_SECRET}
      allowedRoutes:
        namespaces:
          from: All
EOF

echo "Replace the existing Gateway configuration."
kubectl replace -f "${DEPLOYMENT_FILES}/${GATEWAY_NAME}-resource.yaml"

echo "Display TLS Secret metadata."
kubectl get secret ${ASSEMBLY_TLS_SECRET} ${MONGO_TLS_SECRET} -n ${GATEWAY_NAMESPACE}

echo "Display Gateway listeners and reconciliation conditions."
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o yaml

echo "Display application URLs; configure DNS to point both names to the Gateway address."
echo "Assembly URL      : https://${ASSEMBLY_FQDN}/"
echo "Mongo Express URL : https://${MONGO_FQDN}/"

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
