#!/usr/bin/env bash
#-------------+-----------------------------------------------------------------------------+
# Script Name | 91-document-namespace-configuration.sh                                      |
# Updated     | 2026-11-18                                                                  |
# Version     | 8.11                                                                        |
# VCF Version | 9.1.1.0-545627-2026-09                                                      |
# Description | Report configuration and networking for dev-namespace only.                 |
#-------------+-----------------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------------+
# Requirement | Details                                                                     |
#-------------+-----------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                |
# Tools       | curl, jq 1.6+, column, tee, date, dirname and mkdir.                        |
# Inputs      | Review the vCenter connection and credentials below.                        |
# Access      | HTTPS to vCenter; System.Read on the namespace, Supervisor and libraries.   |
# API version | vSphere Automation API 9.1.1; session login/logout and GET requests.        |
# Local files | Write access beside the script; output-YYYY-MM-DD/dev-namespace-report.txt. |
#-------------+-----------------------------------------------------------------------------+

# Stop when a command fails.
set -e

# Retain failures from API requests and report pipelines.
set -o pipefail

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=labadministrator@vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

CONNECT_TIMEOUT=10
REQUEST_TIMEOUT=120
NAMESPACE=dev-namespace

# Resolve the directory containing this script.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Use the local date for the shared daily output directory.
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR=${SCRIPT_DIR}/output-${DATE}
REPORT=${OUTPUT_DIR}/${NAMESPACE}-report.txt

# Create the daily report directory.
mkdir -p ${OUTPUT_DIR}

# Clear the previous report before collecting the latest configuration.
: > ${REPORT}

# Create a vCenter API session.
TOKEN=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -u ${VC_USER}:${VC_PASS} -X POST https://${VCENTER}/api/session | jq -er 'select(type == "string" and length > 0)')

# Read only the configured namespace, including its Supervisor and network settings.
NAMESPACE_INFO=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/namespaces/instances/v2/${NAMESPACE} | jq -e .)

# Resolve the Supervisor hosting this namespace.
SUPERVISOR=$(jq -er '.supervisor | select(type == "string" and length > 0)' <<< "${NAMESPACE_INFO}")

# Read image library settings for this namespace's Supervisor.
IMAGE_SETTINGS=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/namespace-management/supervisors/${SUPERVISOR}/workloads/images/settings | jq -e .)

# Read storage policy names for the namespace storage table.
STORAGE_POLICIES=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/storage/policies | jq -e .)

# Collect namespace VM libraries and Kubernetes libraries from its Supervisor.
LIBRARY_BINDINGS=$(jq -n --argjson ns "${NAMESPACE_INFO}" --argjson images "${IMAGE_SETTINGS}" '
    [($ns.vm_service_spec.content_libraries[]? | {service:"VM Service", id:.}),
     ($ns.content_libraries[]? | {service:"VM Image Service", id:.content_library}),
     ($images.content_libraries[]?
        | select(.supervisor_services == null or (.supervisor_services | index("kubernetes.vmware.com")))
        | {service:"Kubernetes Service (Supervisor)", id:.content_library})]
    | unique_by([.service, .id])')

# Select each associated library once.
LIBRARY_IDS=$(jq -r '[.[].id] | unique[]' <<< "${LIBRARY_BINDINGS}")
LIBRARIES='[]'
ITEMS='[]'

# Read metadata only from the associated libraries.
for LIBRARY_ID in ${LIBRARY_IDS}; do
    # Read the library name, type and synchronization time.
    LIBRARY=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
        -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/content/library/${LIBRARY_ID} | jq -e .)

    # Retain this library with its discovered identifier.
    LIBRARIES=$(jq --arg id ${LIBRARY_ID} --argjson library "${LIBRARY}" '. + [($library + {id:$id})]' <<< "${LIBRARIES}")
done

# Select the Kubernetes libraries associated with this Supervisor.
KUBERNETES_LIBRARIES=$(jq -r '.[] | select(.service == "Kubernetes Service (Supervisor)") | .id' <<< "${LIBRARY_BINDINGS}")

# Read Kubernetes image metadata without downloading images.
for LIBRARY_ID in ${KUBERNETES_LIBRARIES}; do
    # List all item identifiers in this Kubernetes library.
    ITEM_IDS=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
        -H "vmware-api-session-id: ${TOKEN}" --get --data-urlencode library_id=${LIBRARY_ID} \
        https://${VCENTER}/api/content/library/item | jq -r '.[]')

    # Read the metadata of each Kubernetes library item.
    for ITEM_ID in ${ITEM_IDS}; do
        # Read image cache, size, security and certificate metadata.
        ITEM=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
            -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/content/library/item/${ITEM_ID} | jq -e .)

        # Retain the item and its library association.
        ITEMS=$(jq --arg library ${LIBRARY_ID} --argjson item "${ITEM}" '. + [($item + {library:$library})]' <<< "${ITEMS}")
    done
done

# Close the vCenter API session after collecting the report data.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/session

# Format and save the namespace report while displaying it in the terminal.
{
    # Print the report title and source.
    printf '%s\n' '========================================================================================================' \
        'VSPHERE NAMESPACE CONFIGURATION | dev-namespace' \
        '========================================================================================================'

    # Print the report metadata.
    printf 'Generated : %s\nvCenter   : %s\nNamespace : %s\n' ${DATE} ${VCENTER} ${NAMESPACE}

    # Print the namespace identity heading.
    printf '\n%s\n%s\n' 'NAMESPACE AND PLACEMENT' '--------------------------------------------------------------------------------------------------------'

    # Print namespace status, ownership and placement.
    jq -r --arg namespace ${NAMESPACE} '
        ["Namespace", $namespace], ["Description", .description],
        ["Configuration status", .config_status], ["Supervisor ID", .supervisor],
        ["Self-service", (.self_service_namespace // false)],
        ["Creator", ([.creator.domain, .creator.subject] | map(select(. != null and . != "")) | join("\\"))],
        ["Zones", ([.zones[]?.zone] | join(", "))],
        ["Infrastructure policies", ((.infrastructure_policies // []) | join(", "))]
        | map(if . == null or . == "" then "-" else tostring end) | @tsv
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the resource quota heading.
    printf '\n%s\n%s\n' 'RESOURCE QUOTAS AND POD RESERVATIONS' '--------------------------------------------------------------------------------------------------------'

    # Print namespace-wide limits, keeping zero values and missing limits distinct.
    jq -r '
        ["RESOURCE", "LIMIT", "LIMIT (GiB)", "POD RESERVATION", "UNIT"],
        ["CPU", .resource_spec.cpu_limit, "-", .stats.cpu_used, "MHz"],
        ["Memory", .resource_spec.memory_limit,
            (if .resource_spec.memory_limit == null then null else .resource_spec.memory_limit / 1024 end), .stats.memory_used, "MiB"],
        ["Storage", .resource_spec.storage_request_limit,
            (if .resource_spec.storage_request_limit == null then null else .resource_spec.storage_request_limit / 1024 end), .stats.storage_used, "MiB"]
        | map(if . == null then "Not set" else tostring end) | @tsv
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the storage policy heading.
    printf '\n%s\n%s\n' 'ASSIGNED STORAGE POLICIES' '--------------------------------------------------------------------------------------------------------'

    # Resolve only assigned storage policies and print their individual quotas.
    jq -r --argjson policies "${STORAGE_POLICIES}" '
        ["POLICY", "LIMIT (MiB)", "LIMIT (GiB)", "POLICY ID"],
        (.storage_specs[]? | . as $spec |
            [([$policies[] | select(.policy == $spec.policy) | .name] | unique
                | if length == 1 then .[0] else "Unresolved" end), .limit,
                (if .limit == null then null else .limit / 1024 end), .policy])
        | map(if . == null then "Not set" else tostring end) | @tsv
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the namespace permission heading.
    printf '\n%s\n%s\n' 'NAMESPACE ACCESS' '--------------------------------------------------------------------------------------------------------'

    # Print the access list returned for this namespace.
    jq -r '["TYPE", "SUBJECT", "DOMAIN", "ROLE"],
        (.access_list | sort_by(.domain, .subject)[] | [.subject_type, .subject, .domain, .role])
        | map(if . == null or . == "" then "-" else tostring end) | @tsv
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the VM class heading.
    printf '\n%s\n%s\n' 'ALLOWED VM CLASSES' '--------------------------------------------------------------------------------------------------------'

    # Print the VM classes assigned to this namespace.
    jq -r '(.vm_service_spec.vm_classes // []) | sort | if length == 0 then "-" else .[] end' <<< "${NAMESPACE_INFO}"

    # Print the content library heading.
    printf '\n%s\n%s\n' 'CONTENT LIBRARY ASSOCIATIONS' '--------------------------------------------------------------------------------------------------------'

    # Print library details with their namespace or Supervisor service association.
    jq -nr --argjson bindings "${LIBRARY_BINDINGS}" --argjson libraries "${LIBRARIES}" '
        if ($bindings | length) == 0 then "None" else
        $bindings[] | . as $binding | $libraries[] | select(.id == $binding.id) |
        "Service     : \($binding.service)", "Library     : \(.name)",
        "Library ID  : \(.id)", "Type        : \(.type)",
        "Last sync   : \((.last_sync_time // "-") | split("T")[0])", ""
        end
    '

    # Print the Kubernetes library item heading.
    printf '\n%s\n%s\n' 'KUBERNETES SERVICE LIBRARY ITEMS' '--------------------------------------------------------------------------------------------------------'

    # Print Kubernetes image cache, size and security metadata.
    jq -r --argjson libraries "${LIBRARIES}" '
        ["ITEM", "TYPE", "CACHED", "SIZE (GiB)", "SECURITY COMPLIANT", "CERTIFICATE"],
        (sort_by(.library, .name)[] | . as $item |
            [.name, .type, .cached,
                (if .size == null then null else (.size / 1073741824 * 100 | round) / 100 end),
                .security_compliance, .certificate_verification_info.status])
        | map(if . == null or . == "" then "-" else tostring end) | @tsv
    ' <<< "${ITEMS}" | column -t -s $'\t'

    # Print the namespace network heading.
    printf '\n%s\n%s\n' 'NAMESPACE NETWORK CONFIGURATION' '--------------------------------------------------------------------------------------------------------'

    # Print the namespace network provider and its configured VPC or vSphere network.
    jq -r '
        .network_spec as $network |
        ["Network provider", $network.network_provider],
        ["VPC path", $network.vpc_network.vpc],
        ["VPC auto-created", $network.vpc_network.auto_created],
        ["Default subnet size", $network.vpc_network.default_subnet_size],
        ["Private CIDRs", ([$network.vpc_network.vpc_config.private_cidrs[]? |
            "\(.address)/\(.prefix)"] | join(", "))],
        ["Default workload network", $network.vsphere_network.default_workload_network],
        ["vSphere networks", ([$network.vsphere_network.networks[]? |
            "\(.network) (\(.config_status))"] | join(", "))]
        | map(if . == null or . == "" then "-" else tostring end) | @tsv
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the shared subnet heading.
    printf '\n%s\n%s\n' 'SHARED SUBNETS' '--------------------------------------------------------------------------------------------------------'

    # Print shared subnet paths and default workload assignments.
    jq -r '(.network_spec.vpc_network.shared_subnets // []) |
        if length == 0 then "None" else
        (["NAME", "POD DEFAULT", "VM DEFAULT", "NSX PATH"],
         (.[] | [.name, .pod_default, .vm_default, .path]))
        | map(if . == null or . == "" then "-" else tostring end) | @tsv end
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the namespace edge heading.
    printf '\n%s\n%s\n' 'NAMESPACE EDGES' '--------------------------------------------------------------------------------------------------------'

    # Print edge provider and service engine group associations.
    jq -r '(.edges // []) | if length == 0 then "None" else
        (["EDGE ID", "PROVIDER", "AVI SERVICE ENGINE GROUP"],
         (.[] | [.id, .edge_provider, .avi.se_group_name]))
        | map(if . == null or . == "" then "-" else tostring end) | @tsv end
    ' <<< "${NAMESPACE_INFO}" | column -t -s $'\t'

    # Print the configuration message heading.
    printf '\n%s\n%s\n' 'CONFIGURATION MESSAGES' '--------------------------------------------------------------------------------------------------------'

    # Print messages returned by the namespace API.
    jq -r '(.messages // []) | if length == 0 then "None" else
        .[] | [.severity, (.details.localized // .details.default_message // .details.id)] | @tsv end
    ' <<< "${NAMESPACE_INFO}"
} | tee ${REPORT}

# Print the saved report location.
printf '\nReport: %s\n' ${REPORT}
