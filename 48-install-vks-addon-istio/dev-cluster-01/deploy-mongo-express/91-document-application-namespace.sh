#!/bin/bash
#----------------+-------------------------------------------------------------------------+
# Script Name    | 91-document-application-namespace.sh                                    |
# Updated        | 2026-11-18                                                              |
# Version        | 1.21                                                                    |
# VCF Version    | 9.1.1                                                                   |
# Description    | Save Assembly namespace and Istio Gateway API details.                  |
#----------------+-------------------------------------------------------------------------+

#----------------+-------------------------------------------------------------------------+
# Requirement    | Details                                                                 |
#----------------+-------------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                                 |
# Tools          | VCF CLI, kubectl, jq, column, OpenSSL with x509 -ext support.           |
# Authentication | Existing VCF context with refreshable credentials.                      |
# Access         | Workload cluster API connectivity; Gateway API v1 installed.            |
# Permissions    | Read workloads, Gateways, classes, routes and TLS Secrets cluster-wide. |
# Configuration  | Set the target cluster and application namespace.                       |
# Output         | output-YYYY-MM-DD/91-document-application-namespace/                    |
#                | <namespace>-report.txt beside this script.                              |
# Files          | Write access to the report directory beside this script.                |
#----------------+-------------------------------------------------------------------------+

set -e -o pipefail

CLUSTER_NAME=dev-cluster-01
NAMESPACE=dev-mongodb-istio

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

    # Display GatewayClasses and their controllers.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gatewayclass" ${COMMAND_BORDER}

    kubectl get gatewayclass

    # List all Gateway resources across namespaces.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gateways.gateway.networking.k8s.io -A" ${COMMAND_BORDER}

    kubectl get gateways.gateway.networking.k8s.io -A

    # Summarize every Gateway without assuming shared or dedicated ownership.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "Gateway summary: namespace, name, class, requested and assigned addresses, current conditions" ${COMMAND_BORDER}

    kubectl get gateways.gateway.networking.k8s.io -A -o json | \
        jq -r '
            def condition($conditions; $type; $generation):
                ([$conditions[]? | select(.type == $type)] | first) as $condition |
                if $condition == null or $condition.observedGeneration != $generation then "Pending"
                else $condition.status end;
            (["NAMESPACE", "GATEWAY", "CLASS", "REQUESTED_ADDRESS", "ASSIGNED_ADDRESS", "ACCEPTED", "PROGRAMMED"] | @tsv),
            (.items[] | [
                .metadata.namespace, .metadata.name, .spec.gatewayClassName,
                ([.spec.addresses[]?.value] | if length == 0 then "Automatic" else join(",") end),
                ([.status.addresses[]?.value] | if length == 0 then "Pending" else join(",") end),
                condition(.status.conditions; "Accepted"; .metadata.generation),
                condition(.status.conditions; "Programmed"; .metadata.generation)
            ] | @tsv)
        ' | column -t -s $'\t'

    # Display listener configuration and current status for every Gateway.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "Gateway listener summary: all namespaces and Gateways" ${COMMAND_BORDER}

    kubectl get gateways.gateway.networking.k8s.io -A -o json | \
        jq -r '
            def condition($conditions; $type; $generation):
                ([$conditions[]? | select(.type == $type)] | first) as $condition |
                if $condition == null or $condition.observedGeneration != $generation then "Pending"
                else $condition.status end;
            (["NAMESPACE", "GATEWAY", "LISTENER", "PROTOCOL", "PORT", "HOSTNAME", "CERTIFICATE_SECRET", "ATTACHED_ROUTES", "ACCEPTED", "PROGRAMMED", "RESOLVED_REFS"] | @tsv),
            (.items[] as $gateway | $gateway.spec.listeners[] as $listener |
                ([$gateway.status.listeners[]? | select(.name == $listener.name)] | first) as $status |
                [
                    $gateway.metadata.namespace,
                    $gateway.metadata.name,
                    $listener.name,
                    $listener.protocol,
                    ($listener.port | tostring),
                    ($listener.hostname // "All"),
                    ([$listener.tls.certificateRefs[]? |
                        ((.namespace // $gateway.metadata.namespace) + "/" + .name)] |
                        if length == 0 then "-" else join(",") end),
                    ($status.attachedRoutes // "Pending" | tostring),
                    condition($status.conditions; "Accepted"; $gateway.metadata.generation),
                    condition($status.conditions; "Programmed"; $gateway.metadata.generation),
                    condition($status.conditions; "ResolvedRefs"; $gateway.metadata.generation)
                ] | @tsv)
        ' | column -t -s $'\t'


    # Display all Gateway listeners, TLS references and conditions.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get gateways.gateway.networking.k8s.io -A -o yaml" ${COMMAND_BORDER}

    kubectl get gateways.gateway.networking.k8s.io -A -o yaml

    # Display configured listeners and their certificate Secret references for every Gateway.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "Gateway configuration: listener, hostname, protocol, port, TLS mode and certificate Secrets" ${COMMAND_BORDER}

    kubectl get gateways.gateway.networking.k8s.io -A -o json | \
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
    kubectl get gateways.gateway.networking.k8s.io -A -o json | \
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

    # Discover HTTPRoutes across namespaces, including other applications using the Gateways.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get httproutes.gateway.networking.k8s.io -A" ${COMMAND_BORDER}

    kubectl get httproutes.gateway.networking.k8s.io -A

    # Match configured route parents with controller attachment conditions.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "HTTPRoute attachments: namespace, route, hostnames, parent Gateway, listener and current conditions" ${COMMAND_BORDER}

    kubectl get httproutes.gateway.networking.k8s.io -A -o json | \
        jq -r '
            def condition($conditions; $type; $generation):
                ([$conditions[]? | select(.type == $type)] | first) as $condition |
                if $condition == null or $condition.observedGeneration != $generation then "Pending"
                else $condition.status end;
            (["NAMESPACE", "HTTPROUTE", "HOSTNAMES", "PARENT_GATEWAY", "LISTENER", "ACCEPTED", "RESOLVED_REFS"] | @tsv),
            (.items[] as $route | $route.spec.parentRefs[]? |
                select((.group // "gateway.networking.k8s.io") == "gateway.networking.k8s.io" and (.kind // "Gateway") == "Gateway") |
                . as $parent |
                ([$route.status.parents[]? | select(
                    (.parentRef.group // "gateway.networking.k8s.io") == "gateway.networking.k8s.io" and
                    (.parentRef.kind // "Gateway") == "Gateway" and
                    .parentRef.name == $parent.name and
                    (.parentRef.namespace // $route.metadata.namespace) == ($parent.namespace // $route.metadata.namespace) and
                    (.parentRef.sectionName // "") == ($parent.sectionName // "") and
                    (.parentRef.port // 0) == ($parent.port // 0)
                )] | first) as $status |
                [
                    $route.metadata.namespace, $route.metadata.name,
                    ($route.spec.hostnames // ["All"] | join(",")),
                    (($parent.namespace // $route.metadata.namespace) + "/" + $parent.name),
                    ($parent.sectionName // "All"),
                    condition($status.conditions; "Accepted"; $route.metadata.generation),
                    condition($status.conditions; "ResolvedRefs"; $route.metadata.generation)
                ] | @tsv)
        ' | column -t -s $'\t'

    # List application HTTPRoutes.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get httproutes.gateway.networking.k8s.io -n ${NAMESPACE}" ${COMMAND_BORDER}

    kubectl get httproutes.gateway.networking.k8s.io -n ${NAMESPACE}

    # Display HTTPRoute backends, redirects and attachment conditions.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get httproutes.gateway.networking.k8s.io -n ${NAMESPACE} -o yaml" ${COMMAND_BORDER}

    kubectl get httproutes.gateway.networking.k8s.io -n ${NAMESPACE} -o yaml

    # Discover the Istio control plane without assuming its namespace.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get deployments,pods,services -A -l app=istiod -o wide" ${COMMAND_BORDER}

    kubectl get deployments,pods,services -A -l app=istiod -o wide

    # Discover Gateway deployments, Envoy Pods and LoadBalancer Services by their Gateway label.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get deployments,pods,services -A -l gateway.networking.k8s.io/gateway-name -o wide" ${COMMAND_BORDER}

    kubectl get deployments,pods,services -A -l gateway.networking.k8s.io/gateway-name -o wide
} > "${REPORT}" 2>&1

# Display the saved report location.
echo "Report saved: ${REPORT}"
