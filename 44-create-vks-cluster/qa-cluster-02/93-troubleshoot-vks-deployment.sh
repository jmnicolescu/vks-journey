#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 93-troubleshoot-vks-deployment.sh                                     |
# Updated        | 2026-11-15                                                            |
# Version        | 1.5                                                                   |
# VCF Version    | 9.1.1.0-545627-2026-09                                                |
# Description    | Document Supervisor deployment and VKS workload diagnostics.          |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash 3.2+ on macOS or Linux.                                          |
# Tools          | VCF CLI, kubectl, jq, tee, fold, awk, date and mkdir.                 |
# Authentication | Authenticated Supervisor context and refreshable workload context.    |
# Access         | Supervisor and workload APIs; workload refresh must succeed first.    |
# Permissions    | Read Cluster API, VM Operator, events, quotas, limits and PVCs.       |
#                | Read workload nodes, kube-system pods and warning events.             |
# Configuration  | Set cluster name, timeout, Supervisor context and namespace.          |
# APIs           | Kubernetes, Cluster API and VM Operator through API discovery.        |
# Side effects   | Refresh local credentials; finish in the Supervisor context.          |
# Watch commands | Optional commented examples; watch utility for the first one.         |
# Failure policy | Stop on command failure; retain captured output and errors.           |
# Output         | output-YYYY-MM-DD/vks-deployment-troubleshooting-report—<cluster>.txt |
# Files          | Write access beside this script; report replaced each run.            |
#----------------+-----------------------------------------------------------------------+

# Stop when a command or pipeline fails.
set -e -o pipefail

CLUSTER_NAME=qa-cluster-02
REQUEST_TIMEOUT=60
CONTEXT=${CLUSTER_NAME}:${CLUSTER_NAME}
REPORT_TITLE="VKS Deployment Troubleshooting — ${CLUSTER_NAME}"

SUPERVISOR_CONTEXT=supervisor
CLUSTER_NAMESPACE=qa-namespace

# Keep report files private.
umask 077

# Locate the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Capture the local timestamp once for the output directory.
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
DATE=${TIMESTAMP:0:10}
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/vks-deployment-troubleshooting-${CLUSTER_NAME}.txt

# Refresh workload cluster authentication and retain error messages.
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

# Display the command before its output.
printf '\n$ %s\n' "kubectl config use-context ${CONTEXT}"

# Select the workload context without Harbor plugin discovery.
kubectl config use-context ${CONTEXT}

# Read the configured API server address.
API_SERVER=$(kubectl --context=${CONTEXT} config view --minify -o 'jsonpath={.clusters[0].cluster.server}')

# Describe the existing kubeconfig TLS verification setting.
TLS_VERIFICATION=$(kubectl --context=${CONTEXT} config view --minify -o json | jq -r '
    if .clusters[0].cluster["insecure-skip-tls-verify"] == true
    then "Disabled (kubeconfig)" else "Enabled (kubeconfig)" end')

# Create the report directory.
mkdir -p "${OUTPUT_DIR}"

# Display and save the report sections, output and errors.
{
    # Print the report title border at the same width as section boxes.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Pad the title to 87 columns, counting the em dash as one display character.
    printf '%s\n' "${REPORT_TITLE}" | fold -s -w 87 | awk '{ text=$0; gsub(/—/, "-", text); printf "| %s%*s |\n", $0, 87-length(text), "" }'

    # Close the report title box.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Print the workload cluster name.
    printf '%-18s : %s\n' 'Cluster' ${CLUSTER_NAME}

    # Print the existing report text.
    printf '%-18s : %s\n' 'Context' ${CONTEXT}

    # Print the existing report text.
    printf '%-18s : %s\n' 'API server' "${API_SERVER}"

    # Print the existing report text.
    printf '%-18s : %s\n' 'Mode' 'Read-only discovery'

    # Print the existing report text.
    printf '%-18s : %s\n' 'TLS verification' "${TLS_VERIFICATION}"

    # Print the existing report text.
    printf '%-18s : %s\n' 'Namespace' ${CLUSTER_NAMESPACE}

    # Print the existing report text.
    printf 'Supervisor diagnostics cover the deployment namespace; workload warnings cover all namespaces.\n'

    # Identify the management context used for deployment diagnostics.
    printf '%-18s : %s\n' 'Supervisor context' ${SUPERVISOR_CONTEXT}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '1. SUPERVISOR CONTEXT' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl config use-context ${SUPERVISOR_CONTEXT}"

    # Select the Supervisor context without triggering Harbor plugin discovery.
    kubectl config use-context ${SUPERVISOR_CONTEXT}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl config current-context"

    # Confirm the selected context.
    kubectl config current-context

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '2. CLUSTER OVERVIEW' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Inspect the Cluster summary.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o yaml"

    # Inspect the complete Cluster specification, conditions and status.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o yaml

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Describe the Cluster and its associated events.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '3. CONTROL PLANE' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get kubeadmcontrolplanes -n ${CLUSTER_NAMESPACE}"

    # List control planes in the namespace.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get kubeadmcontrolplanes -n ${CLUSTER_NAMESPACE}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe kubeadmcontrolplane -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Describe the control plane using its cluster-name prefix.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe kubeadmcontrolplane -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '4. WORKER MACHINEDEPLOYMENTS' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machinedeployments -n ${CLUSTER_NAMESPACE} -o wide"

    # List worker MachineDeployments and their replica counts.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machinedeployments -n ${CLUSTER_NAMESPACE} -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machinedeployment -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Describe worker MachineDeployments using the cluster-name prefix.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machinedeployment -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '5. WORKER MACHINESETS' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machinesets -n ${CLUSTER_NAMESPACE} -o wide"

    # List machinesets in the deployment namespace.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machinesets -n ${CLUSTER_NAMESPACE} -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machinesets -n ${CLUSTER_NAMESPACE}"

    # Describe machinesets, including conditions and related events.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machinesets -n ${CLUSTER_NAMESPACE}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '6. KUBEADM BOOTSTRAP CONFIGURATION' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get kubeadmconfigs -n ${CLUSTER_NAMESPACE}"

    # List kubeadmconfigs in the deployment namespace.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get kubeadmconfigs -n ${CLUSTER_NAMESPACE}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe kubeadmconfigs -n ${CLUSTER_NAMESPACE}"

    # Describe kubeadmconfigs, including conditions and related events.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe kubeadmconfigs -n ${CLUSTER_NAMESPACE}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '7. MACHINES' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machines -n ${CLUSTER_NAMESPACE} -o wide"

    # List Machines and their provisioning state.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machines -n ${CLUSTER_NAMESPACE} -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machine -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Describe Machines using the cluster-name prefix.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe machine -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '8. VIRTUAL MACHINES' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get virtualmachines -n ${CLUSTER_NAMESPACE} -o wide"

    # List virtual machines and their provisioning state.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get virtualmachines -n ${CLUSTER_NAMESPACE} -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe virtualmachine -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}"

    # Describe virtual machines using the cluster-name prefix.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe virtualmachine -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '9. CLUSTER STATUS AND COMBINED OVERVIEW' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o 'jsonpath={.status.phase}{\"\\n\"}'"

    # Display the Cluster phase when this API version exposes it; a blank result is not a health verdict.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o 'jsonpath={.status.phase}{"\n"}'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o 'jsonpath={.status.conditions}{\"\\n\"}'"

    # Display Cluster conditions, including reasons and messages, without depending on status.phase.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -o 'jsonpath={.status.conditions}{"\n"}'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster,kubeadmcontrolplane,machinedeployment,machine,virtualmachine -n ${CLUSTER_NAMESPACE} -o wide"

    # Show the build resources together, including the control plane.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster,kubeadmcontrolplane,machinedeployment,machine,virtualmachine -n ${CLUSTER_NAMESPACE} -o wide

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '10. EVENTS, QUOTA AND STORAGE' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get events -n ${CLUSTER_NAMESPACE} --sort-by=.metadata.creationTimestamp"

    # Show namespace events in creation-time order; inspect messages for provisioning failures.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get events -n ${CLUSTER_NAMESPACE} --sort-by=.metadata.creationTimestamp

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --types=Warning"

    # Show warning events across the namespace, including child resources.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --types=Warning

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --for=Cluster/${CLUSTER_NAME}"

    # Show events attached directly to the Cluster; child-resource events may appear only above.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --for=Cluster/${CLUSTER_NAME}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe resourcequota -n ${CLUSTER_NAMESPACE}"

    # Inspect namespace resource quotas and their current usage.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe resourcequota -n ${CLUSTER_NAMESPACE}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe limitrange -n ${CLUSTER_NAMESPACE}"

    # Inspect default and maximum resource limits in the namespace.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe limitrange -n ${CLUSTER_NAMESPACE}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pvc -n ${CLUSTER_NAMESPACE} -o wide"

    # List persistent volume claims to identify pending storage requests.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pvc -n ${CLUSTER_NAMESPACE} -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe pvc -n ${CLUSTER_NAMESPACE}"

    # Inspect volume claim status and provisioning events.
    kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s describe pvc -n ${CLUSTER_NAMESPACE}

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '11. FOLLOW PROGRESS (PRESS CTRL+C TO STOP EACH COMMAND)' ${SUPERVISOR_CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the optional interactive command.
    printf '%s\n' "watch -n 5 \"kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster,kubeadmcontrolplane,machinedeployment,machine,virtualmachine -n ${CLUSTER_NAMESPACE} -o wide\""

    # Refresh the combined view every five seconds; requires watch on Linux/macOS.
    # watch -n 5 "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster,kubeadmcontrolplane,machinedeployment,machine,virtualmachine -n ${CLUSTER_NAMESPACE} -o wide"

    # Explain why the continuous watch is not started during report capture.
    echo "Optional interactive command; uncomment it in the script to follow progress."

    # Display the optional interactive command.
    printf '%s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -w"

    # Follow Cluster changes using kubectl only; also usable from Windows.
    # kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get cluster -n ${CLUSTER_NAMESPACE} ${CLUSTER_NAME} -w

    # Explain why the continuous watch is not started during report capture.
    echo "Optional interactive command; uncomment it in the script to follow progress."

    # Display the optional interactive command.
    printf '%s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machines -n ${CLUSTER_NAMESPACE} -o wide -w"

    # Follow Machine changes using kubectl only.
    # kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get machines -n ${CLUSTER_NAMESPACE} -o wide -w

    # Explain why the continuous watch is not started during report capture.
    echo "Optional interactive command; uncomment it in the script to follow progress."

    # Display the optional interactive command.
    printf '%s\n' "kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --watch"

    # Follow new namespace events.
    # kubectl --context=${SUPERVISOR_CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -n ${CLUSTER_NAMESPACE} --watch

    # Explain why the continuous watch is not started during report capture.
    echo "Optional interactive command; uncomment it in the script to follow progress."

    # Print the diagnostic section heading.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the section name and context.
    printf '%s - %s\n' '12. AFTER THE WORKLOAD CLUSTER API IS REACHABLE' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Close the section heading.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl config use-context ${CONTEXT}"

    # Select the VKS workload context.
    kubectl config use-context ${CONTEXT}

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes -o wide"

    # Check node readiness and addresses.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods -n kube-system -o wide"

    # Check system pods for pending, failing or restarting components.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods -n kube-system -o wide

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -A --types=Warning"

    # Show workload-cluster warning events across namespaces.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s events -A --types=Warning

    # Display the command before its output.
    printf '\n$ %s\n' "kubectl config use-context ${SUPERVISOR_CONTEXT}"

    # Return to the Supervisor context for further build troubleshooting.
    kubectl config use-context ${SUPERVISOR_CONTEXT}

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' 'FINAL RESULT' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'
    # Print the existing report text.
    printf '%-18s : %s\n' 'Collection status' 'Completed'

    # Print the existing report text.
    printf '%-18s : %s\n' 'Writes attempted' '0'

} 2>&1 | tee "${REPORT}"

# Display the saved report location.
echo "Report saved: ${REPORT}"
