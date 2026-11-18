#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 91-document-application-namespace.sh                                  |
# Updated        | 2026-11-18                                                            |
# Version        | 1.18                                                                  |
# VCF Version    | 9.1.1                                                                 |
# Description    | Save concise Assembly namespace and Contour Gateway API details.      |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                               |
# Tools          | VCF CLI, kubectl, jq, column, OpenSSL with x509 -ext support.         |
# Authentication | Existing VCF context with refreshable credentials.                    |
# Access         | Workload cluster API connectivity; Gateway API v1 installed.          |
# Permissions    | Read app resources, Gateways, GatewayClasses, routes and TLS Secrets. |
# Configuration  | Set the target cluster and application namespace.                     |
# Output         | output-YYYY-MM-DD/91-document-application-namespace/                  |
#                | <namespace>-report.txt beside this script.                            |
# Files          | Write access to the report directory beside this script.              |
#----------------+-----------------------------------------------------------------------+

set -e -o pipefail

CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-contour
GATEWAY_NAME=contour-gateway
GATEWAY_NAMESPACE=tanzu-system-ingress

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/${NAMESPACE}-report.txt

COMMAND_BORDER=+--------------------------------------------------------------------------------------------------------------------------------------------------------+

# Create the dated output directory.
mkdir -p "${OUTPUT_DIR}"

# Save command output and errors to the namespace report.
{
    # Refresh workload cluster authentication and retain error messages.
    vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

    echo "Application namespace: ${NAMESPACE} | Cluster: ${CLUSTER_NAME} | Captured: ${TIMESTAMP}"

    # Select the workload Kubernetes context.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}" ${COMMAND_BORDER}

    kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

    # Display namespace status and labels.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get namespace ${NAMESPACE} --show-labels" ${COMMAND_BORDER}

    kubectl get namespace ${NAMESPACE} --show-labels

    # List application workloads, Pods and Services.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get all -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    kubectl get all -n ${NAMESPACE} -o wide

    # Display Pod container images.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGES:.spec.containers[*].image'" ${COMMAND_BORDER}

    kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGES:.spec.containers[*].image'

    # List application backend addresses.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get endpointslices -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    kubectl get endpointslices -n ${NAMESPACE} -o wide

    # Verify the Contour GatewayClass and its controller.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gatewayclass" ${COMMAND_BORDER}

    kubectl get gatewayclass

    # List all Gateway resources across namespaces.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gateways -A" ${COMMAND_BORDER}

    kubectl get gateways -A

    # Display all Gateway listeners, TLS references and conditions.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gateways -A -o yaml" ${COMMAND_BORDER}

    kubectl get gateways -A -o yaml

    # Display the shared Gateway listener summary in the report.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "Gateway listener summary: ${GATEWAY_NAMESPACE}/${GATEWAY_NAME}" ${COMMAND_BORDER}

    # Mark conditions from an older Gateway generation as pending reconciliation.
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

    # Display configured listeners and their certificate Secret references for every Gateway.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "Gateway configuration: listener, hostname, protocol, port, TLS mode and certificate Secrets" ${COMMAND_BORDER}

    kubectl get gateways -A -o json | \
        jq '.items[] | .metadata.namespace as $namespace | {
            namespace: $namespace,
            gateway: .metadata.name,
            gatewayClass: .spec.gatewayClassName,
            listeners: [.spec.listeners[] | {
                name, hostname, protocol, port,
                tlsMode: .tls.mode,
                certificates: [.tls.certificateRefs[]? | {
                    group: (.group // ""),
                    kind: (.kind // "Secret"),
                    namespace: (.namespace // $namespace),
                    name
                }]
            }]
        }'

    # Read each referenced TLS Secret once and display only its public certificate details.
    kubectl get gateways -A -o json | \
        jq -r '[.items[] | .metadata.namespace as $namespace |
            .spec.listeners[] | .tls.certificateRefs[]? |
            select((.group // "") == "" and (.kind // "Secret") == "Secret") |
            [(.namespace // $namespace), .name]] | unique[] | @tsv' | \
        while IFS=$'\t' read -r CERT_NAMESPACE CERT_SECRET; do
            # Display the certificate Secret metadata without its data or annotations.
            printf '\n%s\n| %-150s |\n%s\n\n' \
                ${COMMAND_BORDER} "kubectl get secret ${CERT_SECRET} -n ${CERT_NAMESPACE}" ${COMMAND_BORDER}

            kubectl get secret ${CERT_SECRET} -n ${CERT_NAMESPACE}

            # Display the leaf certificate identity, validity, SANs and SHA-256 fingerprint.
            printf '\n%s\n| %-150s |\n%s\n\n' \
                ${COMMAND_BORDER} "Public TLS certificate: ${CERT_NAMESPACE}/${CERT_SECRET} (tls.crt)" ${COMMAND_BORDER}

            kubectl get secret ${CERT_SECRET} -n ${CERT_NAMESPACE} \
                -o jsonpath='{.data.tls\.crt}' | \
                openssl base64 -d -A | \
                openssl x509 -noout -subject -issuer -dates -ext subjectAltName -sha256 -fingerprint
        done

    # Verify listener status and attached HTTPRoute counts for every Gateway.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gateways -A -o json | jq (namespace, gateway, listeners and conditions)" ${COMMAND_BORDER}

    kubectl get gateways -A -o json | \
        jq '.items[] | {
            namespace: .metadata.namespace,
            gateway: .metadata.name,
            listeners: [.status.listeners[]? | {
                name,
                attachedRoutes,
                conditions: [.conditions[]? | {type, status, reason}]
            }]
        }'

    # List application HTTPRoutes.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get httproutes -n ${NAMESPACE}" ${COMMAND_BORDER}

    kubectl get httproutes -n ${NAMESPACE}

    # Display HTTPRoute backends, redirects and attachment conditions.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get httproutes -n ${NAMESPACE} -o yaml" ${COMMAND_BORDER}

    kubectl get httproutes -n ${NAMESPACE} -o yaml

    # Display Contour and Envoy workloads and Service addresses in the ingress namespace.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get deployments,daemonsets,pods,services -n ${GATEWAY_NAMESPACE} -o wide" ${COMMAND_BORDER}

    kubectl get deployments,daemonsets,pods,services -n ${GATEWAY_NAMESPACE} -o wide
} > "${REPORT}" 2>&1

# Display the saved report location.
echo "Report saved: ${REPORT}"
