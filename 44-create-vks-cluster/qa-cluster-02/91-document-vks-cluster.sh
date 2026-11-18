#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 91-document-vks-cluster.sh                                            |
# Updated        | 2026-11-15                                                            |
# Version        | 2.20                                                                  |
# VCF Version    | 9.1.1.0-545627-2026-09                                                |
# Description    | Document VKS networking, workloads, CNI and CSI in 24 sections.       |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash 3.2+ on macOS or Linux.                                          |
# Tools          | VCF CLI, kubectl, jq, tee, fold, sed, sort, paste, awk, date, mkdir.  |
# Authentication | Refreshable VCF workload context and existing kubeconfig.             |
# Configuration  | Set CLUSTER_NAME and REQUEST_TIMEOUT below.                           |
# Access         | Workload API discovery and list access across all namespaces.         |
# APIs           | Kubernetes core, apps, batch, networking, discovery and storage.      |
# Extensions     | Antrea CRDs, volume snapshot CRDs and Metrics API must be available.  |
# Permissions    | Read nodes, workloads, ConfigMaps, networking, storage and events.    |
# Side effects   | Refresh local credentials and select the workload context.            |
# Failure policy | Stop on command failure; retain captured output and errors.           |
# Output         | output-YYYY-MM-DD/91-document-vks-cluster/91-document-vks-cluster.txt |
# Files          | Report replaced each run; no Secret objects are read.                 |
#----------------+-----------------------------------------------------------------------+

# Stop when a command or pipeline fails.
set -e -o pipefail

CLUSTER_NAME=qa-cluster-02
REQUEST_TIMEOUT=60
CONTEXT=${CLUSTER_NAME}:${CLUSTER_NAME}
REPORT_TITLE="VKS Cluster Configuration Report — ${CLUSTER_NAME}"

# Keep report files private.
umask 077

# Locate the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Capture the local timestamp once for the output directory.
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
DATE=${TIMESTAMP:0:10}
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/vks-cluster-configuration-report—${CLUSTER_NAME}.txt

# Refresh workload cluster authentication and retain error messages.
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

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
    printf '%-18s : %s\n' 'Namespace' 'All namespaces'

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '1. NETWORK CIDR AND IP SUMMARY' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read node IPs as addresses, without guessing their subnet masks.
    node_ips=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o 'jsonpath={range .items[*].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}' \
        | sort -u | paste -sd ',' -)

    # Read the actual pod CIDRs allocated to nodes, not an inferred enclosing range.
    pod_cidrs=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o 'jsonpath={range .items[*].spec.podCIDRs[*]}{@}{"\n"}{end}' \
        | sort -u | paste -sd ',' -)

    # Read the configured service CIDRs from the cluster API.
    service_cidrs=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get servicecidrs.networking.k8s.io \
        -o 'jsonpath={range .items[*].spec.cidrs[*]}{@}{"\n"}{end}' \
        | sort -u | paste -sd ',' -)

    # Read assigned LoadBalancer service IPs; these do not specify the backing pool.
    load_balancer_ips=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services --all-namespaces \
        -o 'jsonpath={range .items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[*]}{.ip}{"\n"}{end}' \
        | sed '/^$/d' | sort -u | paste -sd ',' -)

    # Read published ingress IPs; these do not specify a separate ingress subnet.
    ingress_ips=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get ingresses.networking.k8s.io --all-namespaces \
        -o 'jsonpath={range .items[*].status.loadBalancer.ingress[*]}{.ip}{"\n"}{end}' \
        | sed '/^$/d' | sort -u | paste -sd ',' -)

    # Summarize the discovered network CIDRs and assigned IP addresses.
    printf '%-20s %s\n' 'NETWORK' 'CIDRs / IPs'

    # Print the existing report text.
    printf '%-20s %s\n' 'Node IPs' "${node_ips:-<none>}"

    # Print the existing report text.
    printf '%-20s %s\n' 'Pod CIDRs' "${pod_cidrs:-<none>}"

    # Print the existing report text.
    printf '%-20s %s\n' 'Service CIDRs' "${service_cidrs:-<none>}"

    # Print the existing report text.
    printf '%-20s %s\n' 'Load balancer IPs' "${load_balancer_ips:-<none>}"

    # Print the existing report text.
    printf '%-20s %s\n' 'Ingress IPs' "${ingress_ips:-<none>}"

    # Print the existing report text.
    printf '\nPod CIDRs are the ranges allocated to nodes; the full cluster pod range may be larger.\n'

    # 2. Read internal and external node addresses, plus their hostnames.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '2. NODE ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read nodes inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes --sort-by=.metadata.name \
        -o 'custom-columns=NODE:.metadata.name,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,EXTERNAL-IP:.status.addresses[?(@.type=="ExternalIP")].address,HOSTNAME:.status.addresses[?(@.type=="Hostname")].address'

    # 3. Read the pod network ranges assigned to each node.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '3. NODE POD CIDRs' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read nodes inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes --sort-by=.metadata.name \
        -o 'custom-columns=NODE:.metadata.name,POD-CIDR:.spec.podCIDR,POD-CIDRS:.spec.podCIDRs[*]'

    # 4. Read the cluster service network ranges from ServiceCIDR objects.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '4. CLUSTER SERVICE CIDRs' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read servicecidrs.networking.k8s.io fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get servicecidrs.networking.k8s.io \
        -o 'custom-columns=NAME:.metadata.name,SERVICE-CIDRS:.spec.cidrs[*]'

    # 5. Read pod addresses, including both address families, and node placement.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '5. POD ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read pods inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,POD:.metadata.name,PHASE:.status.phase,POD-IP:.status.podIP,POD-IPS:.status.podIPs[*].ip,NODE:.spec.nodeName'

    # 6. Read service virtual addresses and their ports and protocols.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '6. SERVICE CLUSTER ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read services inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,SERVICE:.metadata.name,TYPE:.spec.type,CLUSTER-IPS:.spec.clusterIPs[*],PORTS:.spec.ports[*].port,PROTOCOLS:.spec.ports[*].protocol'

    # 7. Read assigned load balancer addresses; use TYPE to identify LB services.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '7. SERVICE LOAD BALANCER ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read services inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,SERVICE:.metadata.name,TYPE:.spec.type,LB-IPS:.status.loadBalancer.ingress[*].ip,LB-HOSTNAMES:.status.loadBalancer.ingress[*].hostname'

    # Print the existing report text.
    printf 'A LoadBalancer service with no LB address has no assigned address reported yet.\n'

    # 8. Read explicitly configured external IPs and ExternalName DNS targets.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '8. SERVICE EXTERNAL ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read services inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,SERVICE:.metadata.name,TYPE:.spec.type,EXTERNAL-IPS:.spec.externalIPs[*],EXTERNAL-NAME:.spec.externalName'

    # 9. Read backend addresses and readiness from EndpointSlices.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '9. ENDPOINT SLICE ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read endpointslices.discovery.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get endpointslices.discovery.k8s.io --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,SERVICE:.metadata.labels.kubernetes\.io/service-name,SLICE:.metadata.name,ADDRESS-TYPE:.addressType,ALL-ADDRESSES:.endpoints[*].addresses[*],READY-ADDRESSES:.endpoints[?(@.conditions.ready==true)].addresses[*],NOT-READY-ADDRESSES:.endpoints[?(@.conditions.ready==false)].addresses[*],PORTS:.ports[*].port'

    # Print the existing report text.
    printf 'Endpoints with unspecified readiness appear only in ALL-ADDRESSES.\n'

    # 10. Read ingress host rules and published IP or hostname addresses.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '10. INGRESS ADDRESSES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read ingresses.networking.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get ingresses.networking.k8s.io --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,INGRESS:.metadata.name,CLASS:.spec.ingressClassName,HOSTS:.spec.rules[*].host,IPS:.status.loadBalancer.ingress[*].ip,HOSTNAMES:.status.loadBalancer.ingress[*].hostname'

    # 11. Read allocated node ports, including those used by LoadBalancer services.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '11. SERVICE NODE PORTS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read services inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,SERVICE:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].port,NODEPORTS:.spec.ports[*].nodePort,PROTOCOLS:.spec.ports[*].protocol'

    # Extend the original IP inventory with cluster and component configuration.

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '12. CLUSTER IDENTITY' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read the inventory and retain any failure in the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s config view --minify -o 'jsonpath=API endpoint: {.clusters[0].cluster.server}{"\n"}'

    # Read the inventory and retain any failure in the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s version -o json | jq -er '
      .serverVersion.gitVersion
      | select(type == "string" and length > 0)
      | "Kubernetes server: \(.)"'

    # Read nodes fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      "Node count: \(.items | length)"
    '

    # Read namespaces fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      "Namespace count: \(.items | length)"
    '

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '13. NODE CONFIGURATION AND CONDITIONS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read nodes inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o wide

    # Read nodes fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | "\nNode: \(.metadata.name)",
        "OS: \(.status.nodeInfo.osImage)",
        "Kernel: \(.status.nodeInfo.kernelVersion)",
        "Runtime: \(.status.nodeInfo.containerRuntimeVersion)",
        "Unschedulable: \(.spec.unschedulable // false)",
        "Zone: \(.metadata.labels["topology.kubernetes.io/zone"] // "<none>")",
        "Region: \(.metadata.labels["topology.kubernetes.io/region"] // "<none>")",
        (.spec.taints[]?
          | "Taint: \(.key)=\(.value // ""): \(.effect)"),
        (.status.conditions[]
          | "Condition: \(.type)=\(.status); reason=\(.reason); transition=\(.lastTransitionTime); message=\(.message)")
    '

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '14. NODE RESOURCE CAPACITY' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read nodes inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes \
        -o 'custom-columns=NODE:.metadata.name,CPU-CAPACITY:.status.capacity.cpu,CPU-ALLOCATABLE:.status.allocatable.cpu,MEMORY-CAPACITY:.status.capacity.memory,MEMORY-ALLOCATABLE:.status.allocatable.memory,PODS-CAPACITY:.status.capacity.pods,PODS-ALLOCATABLE:.status.allocatable.pods,EPHEMERAL-ALLOCATABLE:.status.allocatable.ephemeral-storage'

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '15. WORKLOAD INVENTORY' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read deployments,statefulsets,daemonsets,jobs,cronjobs inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get deployments,statefulsets,daemonsets,jobs,cronjobs --all-namespaces

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '16. POD STATUS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read the pod status table for display and status flags.
    pods_output=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods -A -o wide)

    # Print the existing report text.
    printf '%s\n' "${pods_output}"

    # Print the existing report text.
    printf '%s\n' "${pods_output}" | awk '
      NR > 1 && NF >= 4 {
        pods++
        if ($4 != "Running") {
          # Print the existing report text.
          printf "FLAG: %s/%s has status %s (not Running).\n", $1, $2, $4
          flagged++
        }
      }
      END {
        if (pods == 0) print "No pods returned."
        else if (flagged == 0) print "All listed pods have status Running."
        else printf "%d pod(s) have a status other than Running.\n", flagged
      }'

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '17. STORAGE CLASSES AND VOLUMES' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read storageclasses inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get storageclasses

    # Read storageclasses fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get storageclasses \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | "\nStorageClass: \(.metadata.name)",
        "Default: \(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] // "false")",
        "Provisioner: \(.provisioner)",
        "Reclaim policy: \(.reclaimPolicy)",
        "Binding mode: \(.volumeBindingMode)",
        "Expansion allowed: \(.allowVolumeExpansion // false)",
        "Allowed topology: \(.allowedTopologies // [] | tojson)",
        ((.parameters // {})
          | to_entries[]
          | select(.key | test(
              "^(storagepolicyname|storagepolicyid|datastoreurl|fstype|csi.storage.k8s.io/fstype|svstorageclass|storagepool|type)$";
              "i"))
          | "Parameter: \(.key)=\(.value)")
    '

    # Read persistentvolumeclaims inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get persistentvolumeclaims --all-namespaces

    # Read persistentvolumes inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get persistentvolumes

    # Read persistentvolumes fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get persistentvolumes \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      "Volume: \(.metadata.name); driver=\(.spec.csi.driver // "<non-CSI>"); handle=\(.spec.csi.volumeHandle // "<none>"); mode=\(.spec.volumeMode); mountOptions=\(.spec.mountOptions // [] | tojson); nodeAffinity=\(.spec.nodeAffinity // {} | tojson)"
    '

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '18. NAMESPACE CONFIGURATION' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read namespaces inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.name,STATUS:.status.phase,PSA-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce,PSA-AUDIT:.metadata.labels.pod-security\.kubernetes\.io/audit,PSA-WARN:.metadata.labels.pod-security\.kubernetes\.io/warn'

    # Read resourcequotas fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get resourcequotas --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      "Quota: \(.metadata.namespace)/\(.metadata.name)\nHard: \(.status.hard // .spec.hard | tojson)\nUsed: \(.status.used // {} | tojson)\nScopes: \(.spec.scopes // [] | tojson)"
    '

    # Read limitranges fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get limitranges --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      "LimitRange: \(.metadata.namespace)/\(.metadata.name)", (.spec.limits[] |
      tojson)
    '

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '19. CLUSTER COMPONENTS AND CNI / CSI WORKLOADS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read pods fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | select(.metadata.namespace == "kube-system"
          or (.metadata.namespace | startswith("vmware-system-"))
          or any(.spec.containers[]?; .image | test("antrea|cilium|calico|flannel|csi|kube-proxy"; "i")))
      | "Component: \(.metadata.namespace)/\(.metadata.name)",
        "  Node: \(.spec.nodeName // "<none>"); phase: \(.status.phase // "<none>")",
        (.spec.containers[]? | "  Container: \(.name); image: \(.image)"),
        (.status.containerStatuses[]? | "  Status: \(.name); ready: \(.ready); restarts: \(.restartCount)")
    '

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '20. CNI AND CSI CONFIGURATION SETTINGS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf 'Explicit ConfigMap settings follow; omitted settings do not establish effective defaults.\nSecret contents and node-local CNI files are not collected.\n'

    # Read configmaps fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get configmaps --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      def network_settings:
        split("\n")
        | reduce .[] as $line (
            {keep: false, lines: []};
            if ($line | test("^[A-Za-z]")) then
              .keep = ($line | test(
                "^(featureGates|trafficEncapMode|tunnelType|mtu|defaultMTU|noSNAT|serviceCIDR|serviceCIDRv6|" +
                "trafficEncryptionMode|enableIPv4|enableIPv6|antreaProxy|nodePortLocal|hostGateway|" +
                "transportInterface|transportInterfaceCIDRs|multicast|enablePrometheusMetrics|apiPort):"))
            else .
            end
            | if .keep and ($line | test("^\\s*(#|$)") | not) then
                .lines += [$line]
              else .
              end
          )
        | .lines
        | join("\n");
      .items[]
      | select(
          (.metadata.name | test("antrea|cilium|calico|flannel|csi|kube-proxy"; "i"))
          and (.metadata.name | test("\\.app($|-change-)") | not)
        )
      | "\nConfigMap: \(.metadata.namespace)/\(.metadata.name)",
        "Available keys: \((.data // {}) | keys | join(", "))",
        ((.data // {})
          | to_entries[]
          | select(
              (.key | test("^(antrea-agent.conf|antrea-controller.conf)$"))
              or (.value | test("^(true|false)$"))
              or (.key | test(
                "^(tunnel|routing-mode|tunnel-protocol|mtu|enable-ipv4|enable-ipv6|ipam|" +
                "kube-proxy-replacement|cluster-pool-ipv4-cidr|cluster-pool-ipv4-mask-size)$"))
            )
          | "Setting: \(.key)",
            (if (.key | test("^antrea-")) then .value | network_settings
             else .value
             end))
    '

    # Read configmaps fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get configmaps --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      select(.metadata.name == "kube-proxy") |
      (.data["config.conf"] // "") |
      split("\n")[] |
      select(test("^(mode|clusterCIDR|bindAddress|metricsBindAddress|healthzBindAddress|detectLocalMode):"))
    '

    # Read configmaps fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get configmaps --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | select(.data["antrea-cni.conflist"] != null)
      | "CNI plugin configuration: \(.metadata.namespace)/\(.metadata.name)",
        (.data["antrea-cni.conflist"]
          | fromjson
          | "Network: \(.name); CNI specification: \(.cniVersion)",
            (.plugins[]
              | "Plugin: \(.type); IPAM: \(.ipam.type // "<none>"); MTU: \(.mtu // "<not explicit>"); capabilities: \(.capabilities // {} | tojson)"))
    '

    # Read configmaps fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get configmaps --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | select(.data["cns-csi.conf"] != null)
      | "CSI configuration: \(.metadata.namespace)/\(.metadata.name)",
        (.data["cns-csi.conf"]
          | split("\n")[]
          | select(test(
              "^\\s*(cluster-id|cluster-distribution|supervisor-id|supervisor-endpoint|supervisor-port|" +
              "port|insecure-flag|datacenters|ca-file|tanzu-kubernetes-cluster-uid|" +
              "tanzu-kubernetes-cluster-name|uid|name)\\s*=";
              "i")))
    '

    # Read networkpolicies.networking.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get networkpolicies.networking.k8s.io --all-namespaces

    # Read networkpolicies.networking.k8s.io fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get networkpolicies.networking.k8s.io --all-namespaces \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      "Policy: \(.metadata.namespace)/\(.metadata.name)\nSpecification: \(.spec | tojson)"
    '

    # Read antreaagentinfos.crd.antrea.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get antreaagentinfos.crd.antrea.io

    # Read antreacontrollerinfos.crd.antrea.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get antreacontrollerinfos.crd.antrea.io

    # Read networkpolicies.crd.antrea.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get networkpolicies.crd.antrea.io --all-namespaces

    # Read clusternetworkpolicies.crd.antrea.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get clusternetworkpolicies.crd.antrea.io

    # Read ippools.crd.antrea.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get ippools.crd.antrea.io

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '21. CSI DRIVERS, NODE REGISTRATION AND ATTACHMENTS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read csidrivers.storage.k8s.io fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get csidrivers.storage.k8s.io \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[] |
      "\nCSI driver: \(.metadata.name)\nSettings: \(.spec | tojson)"
    '

    # Read csinodes.storage.k8s.io fields for the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get csinodes.storage.k8s.io \
        -o json |
      jq -e 'if (.items | type) == "array" then . else error("Expected resource items array") end' |
      jq -r '
      .items[]
      | .metadata.name as $node
      | .spec.drivers[]?
      | "Node: \($node)",
        "Driver: \(.name)",
        "Driver node ID: \(.nodeID)",
        "Topology keys: \(.topologyKeys | join(", "))",
        "Volume limit: \(.allocatable.count // "<not reported>")\n"
    '

    # Read volumeattachments.storage.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get volumeattachments.storage.k8s.io \
        -o 'custom-columns=ATTACHMENT:.metadata.name,DRIVER:.spec.attacher,NODE:.spec.nodeName,PV:.spec.source.persistentVolumeName,ATTACHED:.status.attached,ATTACH-ERROR:.status.attachError.message,DETACH-ERROR:.status.detachError.message'

    # Read csistoragecapacities.storage.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get csistoragecapacities.storage.k8s.io --all-namespaces \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.storageClassName,CAPACITY:.capacity,MAX-VOLUME:.maximumVolumeSize,TOPOLOGY:.nodeTopology'

    # Read volumesnapshotclasses.snapshot.storage.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get volumesnapshotclasses.snapshot.storage.k8s.io

    # Read volumesnapshots.snapshot.storage.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get volumesnapshots.snapshot.storage.k8s.io --all-namespaces

    # Read volumesnapshotcontents.snapshot.storage.k8s.io inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get volumesnapshotcontents.snapshot.storage.k8s.io

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '22. RECENT WARNING EVENTS' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf 'Events currently retained by the API; this is not a historical audit log.\n'

    # Read events inventory using the selected context.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get events --all-namespaces --field-selector=type=Warning --sort-by=.metadata.creationTimestamp \
        -o 'custom-columns=NAMESPACE:.metadata.namespace,OBJECT-KIND:.involvedObject.kind,OBJECT:.involvedObject.name,REASON:.reason,COUNT:.count,FIRST-SEEN:.firstTimestamp,LAST-SEEN:.lastTimestamp,EVENT-TIME:.eventTime,SERIES-LAST:.series.lastObservedTime,MESSAGE:.message'

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '23. CURRENT RESOURCE USAGE' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Read the inventory and retain any failure in the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s top nodes

    # Read the inventory and retain any failure in the report.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s top pods --all-namespaces

    # Print the existing report text.
    printf '\n%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf '%s - %s\n' '24. NAMESPACE POD IMAGE' ${CONTEXT} | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

    # Print the existing report text.
    printf '%s\n' '-------------------------------------------------------------------------------------------'

    # Print the existing report text.
    printf 'Configured images; one row per regular, init or ephemeral container.\n'

    # Read and format regular, init and ephemeral container images.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods --all-namespaces -o json |
        jq -r '
      def containers: (.spec.containers // []) + (.spec.initContainers // []) + (.spec.ephemeralContainers // []);
      if (.items | type) != "array" then error("Expected PodList items array")
      elif any(.items[];
        (.metadata.namespace | type) != "string" or (.metadata.name | type) != "string" or
        (.spec.containers | type) != "array" or (.spec.containers | length) == 0 or
        ((.spec.initContainers // []) | type) != "array" or
        ((.spec.ephemeralContainers // []) | type) != "array")
      then error("Invalid pod metadata or container lists")
      elif any(.items[] | containers[]; (.image | type) != "string" or .image == "")
      then error("Missing container image reference")
      else
        .items | sort_by(.metadata.namespace, .metadata.name)[] | . as $pod |
        containers[] | [$pod.metadata.namespace, $pod.metadata.name, .image] | @tsv
      end' |
        awk -F '\t' '
      BEGIN { widths[1]=9; widths[2]=3; widths[3]=15 }
      {
        for (column=1; column<=3; column++) {
          values[NR,column]=$column
          if (length($column)>widths[column]) widths[column]=length($column)
        }
      }
      END {
        # Print the existing report text.
        printf "%-*s | %-*s | %-*s\n", widths[1], "NAMESPACE", widths[2], "POD", widths[3], "CONTAINER IMAGE"
        for (column=1; column<=3; column++) {
          for (i=0; i<widths[column]; i++) printf "-"
          # Print the existing report text.
          printf "%s", (column<3 ? "-+-" : "\n")
        }
        for (record=1; record<=NR; record++)
          # Print the existing report text.
          printf "%-*s | %-*s | %s\n", widths[1], values[record,1], widths[2], values[record,2], values[record,3]
        if (NR==0) print "No pods returned."
      }
    '

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
