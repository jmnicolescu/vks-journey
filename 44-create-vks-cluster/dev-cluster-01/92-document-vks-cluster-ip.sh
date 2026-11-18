#!/bin/bash
#----------------+---------------------------------------------------------------------------+
# Script Name    | 92-document-vks-cluster-ip.sh                                             |
# Updated        | 2026-11-15                                                                |
# Version        | 4.13                                                                      |
# VCF Version    | 9.1.1.0-545627-2026-09                                                    |
# Description    | Document VKS network CIDRs, IP addresses and service endpoints.           |
#----------------+---------------------------------------------------------------------------+

#----------------+---------------------------------------------------------------------------+
# Requirement    | Details                                                                   |
#----------------+---------------------------------------------------------------------------+
# Runtime        | Bash 3.2+ on macOS or Linux.                                              |
# Tools          | VCF CLI, kubectl, jq, tee, fold, sed, sort, paste, awk, column, date.     |
# Files          | mkdir, rm; write access to the report directory beside this script.       |
# Authentication | Refreshable VCF workload context and existing kubeconfig.                 |
# Configuration  | Set CLUSTER_NAME and REQUEST_TIMEOUT below.                               |
# Access         | Workload API discovery and list access across all namespaces.             |
# APIs           | Kubernetes core v1, networking.k8s.io and discovery.k8s.io.               |
# Permissions    | Read nodes, namespaces, pods, services, ingress and EndpointSlices.       |
# Side effects   | Refresh local credentials and select the workload context.                |
# Failure policy | Stop on command failure; retain captured output and errors.               |
# Output         | output-YYYY-MM-DD/vks-cluster-ip-report—<cluster>.txt; replaced each run. |
# Working file   | vks-cluster-ip-nodes—<cluster>.json; removed after successful collection. |
#----------------+---------------------------------------------------------------------------+

# Stop when a command or pipeline fails.
set -e -o pipefail

CLUSTER_NAME=dev-cluster-01
REQUEST_TIMEOUT=60
CONTEXT=${CLUSTER_NAME}:${CLUSTER_NAME}
REPORT_TITLE="VKS Cluster IP Report — ${CLUSTER_NAME}"

# Keep report files private.
umask 077

# Locate the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Capture the local timestamp once for the output directory.
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
DATE=${TIMESTAMP:0:10}
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/vks-cluster-ip-report—${CLUSTER_NAME}.txt
NODE_INVENTORY=${OUTPUT_DIR}/vks-cluster-ip-nodes—${CLUSTER_NAME}.json

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

    # Read namespaces for the detailed address inventories.
    namespaces=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get namespaces \
        -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}')

    # Save node allocations for namespace placement and CIDR associations.
    kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get nodes -o json > "${NODE_INVENTORY}"

    # Start the namespace subsection numbering.
    namespace_index=0

    # Keep every namespace, including namespaces with no network objects.
    for namespace in ${namespaces}; do

      # Set namespace_index for this run.
      namespace_index=$((namespace_index + 1))

      # Print the existing report text.
      printf '\n%s\n' '-------------------------------------------------------------------------------------------'

      # Print the existing report text.
      printf '%s - %s\n' "12.${namespace_index} NAMESPACE IP REPORT - ${namespace}" "${CONTEXT}" | fold -s -w 87 | awk '{ printf "| %-87s |\n", $0 }'

      # Print the existing report text.
      printf '%s\n' '-------------------------------------------------------------------------------------------'

      # Read pod addresses and workload placement for this namespace.
      pods_json=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get pods -n "${namespace}" -o json)

      # Read service addresses and ports for this namespace.
      services_json=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get services -n "${namespace}" -o json)

      # Read ingress routes and published addresses for this namespace.
      ingresses_json=$(kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get ingresses.networking.k8s.io -n "${namespace}" -o json)

      # Count distinct current pod addresses separately from shared host-network addresses.
      printf '\nIP USAGE SUMMARY\n'

      # Print the existing report text.
      printf '%s\n' "${pods_json}" | jq -r '
        def ips: (.status.podIPs // [{ip: .status.podIP}])[] | .ip | select(. != null and . != "");
        [.items[] | select(.status.phase != "Succeeded" and .status.phase != "Failed")] as $active |
        "Pods returned: \(.items | length)",
        "Active non-host-network pods: \([$active[] | select(.spec.hostNetwork != true)] | length)",
        "Distinct active pod IPs: \([$active[] | select(.spec.hostNetwork != true) | ips] | unique | length)",
        "Active host-network pods (share node addresses): \([$active[] | select(.spec.hostNetwork == true)] | length)",
        "Active pods without an assigned IP: \([$active[] | select([ips] | length == 0)] | length)"'

      # Print the existing report text.
      printf '%s\n' "${services_json}" | jq -r '
        def clusterips: (.spec.clusterIPs // [.spec.clusterIP])[] | select(. != null and . != "None" and . != "");
        "Services: \(.items | length)",
        "Distinct service ClusterIPs: \([.items[] | clusterips] | unique | length)",
        "Headless services: \([.items[] | select(.spec.clusterIP == "None")] | length)",
        "LoadBalancer services: \([.items[] | select(.spec.type == "LoadBalancer")] | length)",
        "Distinct assigned LB IPs: \([.items[] | select(.spec.type == "LoadBalancer") | .status.loadBalancer.ingress[]?.ip | select(. != null)] | unique | length)",
        "Distinct assigned LB hostnames: \([.items[] | select(.spec.type == "LoadBalancer") | .status.loadBalancer.ingress[]?.hostname | select(. != null)] | unique | length)",
        "LB services without a published address: \([.items[] | select(.spec.type == "LoadBalancer") | select([.status.loadBalancer.ingress[]? | (.ip // .hostname) | select(. != null and . != "")] | length == 0)] | length)"'

      # Print the existing report text.
      printf '%s\n' "${ingresses_json}" | jq -r '
        "Ingress objects: \(.items | length)",
        "Distinct ingress IPs: \([.items[].status.loadBalancer.ingress[]?.ip | select(. != null)] | unique | length)",
        "Distinct ingress hostnames: \([.items[].status.loadBalancer.ingress[]?.hostname | select(. != null)] | unique | length)"'

      # Associate active workload placement with node CIDRs without inventing namespace allocations.
      printf '\nCIDR USAGE CONTEXT\nShared cluster service CIDRs: %s\n' "${service_cidrs:-<none>}"

      # Print the existing report text.
      printf 'Node pod CIDRs are shared across namespaces; these are placement associations, not reserved namespace ranges.\n'

      # Print the existing report text.
      printf 'Counts exclude host-network and terminal pods. Addresses are observed, not a free-IP or utilization estimate.\n'

      # Print the existing report text.
      printf '%s\n' "${pods_json}" | jq -r --slurpfile node_inventory "${NODE_INVENTORY}" '
        def ips: (.status.podIPs // [{ip: .status.podIP}])[] | .ip | select(. != null and . != "");
        [.items[] | select(.spec.hostNetwork != true and .status.phase != "Succeeded" and .status.phase != "Failed" and .spec.nodeName != null)] |
        if length == 0 then "No active non-host-network pods assigned to nodes."
        else group_by(.spec.nodeName)[] | . as $pods | .[0].spec.nodeName as $name |
          "Node: \($name)",
          "  Pod CIDRs: \([$node_inventory[0].items[] | select(.metadata.name == $name) | (.spec.podCIDRs // [.spec.podCIDR])[] | select(. != null)] | if length == 0 then "<not reported>" else join(", ") end)",
          "  Namespace pods: \($pods | length); distinct observed IPs: \([$pods[] | ips] | unique | length)"
        end'

      # Print the existing report text.
      printf 'LB and ingress addresses may be shared; their backing pool CIDRs are not exposed by these objects.\n'

      # List pod addresses from the same response used for the summary.
      printf '\nPOD IP ADDRESSES\n'

      # Print the existing report text.
      printf '%s\n' "${pods_json}" | jq -r '
        def value: if . == null or . == "" then "<none>" else tostring end;
        if (.items | length) == 0 then "No pods returned."
        else (["POD", "PHASE", "HOST-NETWORK", "POD-IPS", "NODE"],
          (.items[] | [.metadata.name, .status.phase, (.spec.hostNetwork // false),
            ([ (.status.podIPs // [{ip: .status.podIP}])[]?.ip | select(. != null)] | join(",")), .spec.nodeName] | map(value))) | @tsv end' | column -t -s $'\t'

      # Keep port, target port, protocol, and NodePort associations on separate service rows.
      printf '\nSERVICES AND PORTS\n'

      # Print the existing report text.
      printf '%s\n' "${services_json}" | jq -r '
        def value: if . == null or . == "" then "<none>" else tostring end;
        if (.items | length) == 0 then "No services returned."
        else (["SERVICE", "TYPE", "CLUSTER-IPS", "EXTERNAL-IPS", "EXTERNAL-NAME", "PORT", "TARGET", "PROTOCOL", "NODEPORT"],
          (.items[] | . as $s | (if (.spec.ports | length) > 0 then .spec.ports[] else {} end) |
            [$s.metadata.name, $s.spec.type, (($s.spec.clusterIPs // [$s.spec.clusterIP]) | map(select(. != null)) | join(",")),
             ($s.spec.externalIPs // [] | join(",")), $s.spec.externalName, .port, .targetPort, .protocol, .nodePort] | map(value))) | @tsv end' | column -t -s $'\t'

      # Show only LoadBalancer services, including those awaiting an address.
      printf '\nLOAD BALANCERS\n'

      # Print the existing report text.
      printf '%s\n' "${services_json}" | jq -r '
        [.items[] | select(.spec.type == "LoadBalancer")] |
        if length == 0 then "No LoadBalancer services returned."
        else (["SERVICE", "ASSIGNED-IPS", "ASSIGNED-HOSTNAMES", "REQUESTED-IP", "EXTERNAL-TRAFFIC-POLICY"],
          (.[] | [.metadata.name, ([.status.loadBalancer.ingress[]?.ip | select(. != null)] | join(",")),
            ([.status.loadBalancer.ingress[]?.hostname | select(. != null)] | join(",")), .spec.loadBalancerIP, .spec.externalTrafficPolicy] |
            map(if . == null or . == "" then "<none>" else tostring end))) | @tsv end' | column -t -s $'\t'

      # Preserve ingress host/path/backend relationships, published addresses, and TLS references.
      printf '\nINGRESS ROUTES\n'

      # Print the existing report text.
      printf '%s\n' "${ingresses_json}" | jq -r '
        def backend: if .service then "\(.service.name):\(.service.port.number // .service.port.name)"
          elif .resource then "\(.resource.kind)/\(.resource.name)" else "<none>" end;
        if (.items | length) == 0 then "No ingress objects returned."
        else .items[] | "Ingress: \(.metadata.name); class=\(.spec.ingressClassName // .metadata.annotations["kubernetes.io/ingress.class"] // "<none>")",
          "  Published addresses: \([.status.loadBalancer.ingress[]? | .ip // .hostname] | if length == 0 then "<none>" else join(", ") end)",
          "  Default backend: \(.spec.defaultBackend | backend)",
          (.spec.rules[]? | (.host // "*") as $host | .http.paths[]? | "  Route: \($host)\(.path // "/") [\(.pathType // "<none>")] -> \(.backend | backend)"),
          (.spec.tls[]? | "  TLS: hosts=\(.hosts // [] | join(",")); Secret reference=\(.secretName // "<none>")") end'

      # Include service backends and their readiness in the namespace network inventory.
      printf '\nSERVICE ENDPOINTS\n'

      # Read the requested Kubernetes inventory.
      kubectl --context=${CONTEXT} --request-timeout=${REQUEST_TIMEOUT}s get endpointslices.discovery.k8s.io -n "${namespace}" \
        -o 'custom-columns=SERVICE:.metadata.labels.kubernetes\.io/service-name,SLICE:.metadata.name,TYPE:.addressType,ADDRESSES:.endpoints[*].addresses[*],READY-ADDRESSES:.endpoints[?(@.conditions.ready==true)].addresses[*],NOT-READY-ADDRESSES:.endpoints[?(@.conditions.ready==false)].addresses[*],PORTS:.ports[*].port'
    done

    # Remove the node inventory after all namespace reports succeed.
    rm -f "${NODE_INVENTORY}"

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
