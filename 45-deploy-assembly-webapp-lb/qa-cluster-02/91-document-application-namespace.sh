#!/bin/bash
#----------------+--------------------------------------------------------------------------+
# Script Name    | 91-document-application-namespace.sh                                     |
# Updated        | 2026-11-18                                                               |
# Version        | 1.6                                                                      |
# VCF Version    | 9.1.1                                                                    |
# Description    | Save namespace, container images and LoadBalancer details to one report. |
#----------------+--------------------------------------------------------------------------+

#----------------+--------------------------------------------------------------------------+
# Requirement    | Details                                                                  |
#----------------+--------------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                                  |
# Tools          | VCF CLI, kubectl, date, mkdir, dirname and standard utilities.           |
# Authentication | Existing VCF context with credentials that can be refreshed.             |
# Access         | Workload cluster API connectivity.                                       |
# Permissions    | Read the application namespace and its resources.                        |
# Configuration  | Set the target cluster name and application namespace.                   |
# Output         | output-YYYY-MM-DD/<namespace>-report.txt beside this script.             |
# Files          | Write access to the report directory beside this script.                 |
#----------------+--------------------------------------------------------------------------+

# Stop when a command fails.
set -e

CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-lb


SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/${NAMESPACE}-report.txt

COMMAND_BORDER=+--------------------------------------------------------------------------------------------------------------------------------------------------------+

# Create the dated output directory.
mkdir -p ${OUTPUT_DIR}

# Save Kubernetes command output and errors to the namespace report.
{
    # Refresh workload cluster authentication and retain error messages.
    vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}" ${COMMAND_BORDER}

    # Select the workload Kubernetes context.
    kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

    # Identify the application namespace report.
    echo "Application namespace: ${NAMESPACE} | Cluster: ${CLUSTER_NAME} | Date: ${DATE}"

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl describe namespace ${NAMESPACE}" ${COMMAND_BORDER}

    # Capture namespace labels, annotations, quotas and limits.
    kubectl describe namespace ${NAMESPACE}

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get all -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    # List deployed workloads, Pods and Services with their addresses.
    kubectl get all -n ${NAMESPACE} -o wide

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGES:.spec.containers[*].image'" ${COMMAND_BORDER}

    # Capture the configured container image tags for each Pod.
    kubectl get pods -n ${NAMESPACE} \
        -o custom-columns='POD:.metadata.name,IMAGES:.spec.containers[*].image'

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGE_IDS:.status.containerStatuses[*].imageID'" ${COMMAND_BORDER}

    # Capture the container image IDs reported by the runtime for each Pod.
    kubectl get pods -n ${NAMESPACE} \
        -o custom-columns='POD:.metadata.name,IMAGE_IDS:.status.containerStatuses[*].imageID'

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get services -n ${NAMESPACE} -o yaml" ${COMMAND_BORDER}

    # Capture complete Service settings, traffic policies, annotations and LoadBalancer status.
    kubectl get services -n ${NAMESPACE} -o yaml

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get endpointslices -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    # List backend EndpointSlices and their ports and addresses.
    kubectl get endpointslices -n ${NAMESPACE} -o wide

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get ingresses,networkpolicies -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    # List ingress addresses, ports and network policy selectors.
    kubectl get ingresses,networkpolicies -n ${NAMESPACE} -o wide

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get persistentvolumeclaims,horizontalpodautoscalers,poddisruptionbudgets -n ${NAMESPACE} -o wide" ${COMMAND_BORDER}

    # List storage bindings, scaling status and disruption budgets.
    kubectl get persistentvolumeclaims,horizontalpodautoscalers,poddisruptionbudgets -n ${NAMESPACE} -o wide

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get configmaps,secrets -n ${NAMESPACE}" ${COMMAND_BORDER}

    # List ConfigMap and Secret types and entry counts without dumping values.
    kubectl get configmaps,secrets -n ${NAMESPACE}

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get serviceaccounts,roles,rolebindings -n ${NAMESPACE}" ${COMMAND_BORDER}

    # List service accounts, roles and role binding references.
    kubectl get serviceaccounts,roles,rolebindings -n ${NAMESPACE}

    # Print the Kubernetes command in a box before its output.
    printf '\n%s\n| %-150s |\n%s\n\n' \
        ${COMMAND_BORDER} "kubectl get events -n ${NAMESPACE} --sort-by=.metadata.creationTimestamp" ${COMMAND_BORDER}

    # Capture namespace events in creation order.
    kubectl get events -n ${NAMESPACE} --sort-by=.metadata.creationTimestamp
} > ${REPORT} 2>&1

# Display the saved report location.
echo "Report saved: ${REPORT}"
