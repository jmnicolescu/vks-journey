#!/usr/bin/env bash
#-------------+------------------------------------------------------------------------------------+
# Script Name | 30-create-namespace-template.sh                                                    |
# Updated     | 2026-11-15                                                                         |
# Version     | 1.20                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                             |
# Description | Configure a self-service namespace template and activate Namespace Service.        |
#-------------+------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------+
# Requirement | Details                                                                            |
#-------------+------------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                       |
# Tools       | curl 7.76+, jq, tee, mkdir and dirname.                                            |
# Inputs      | Review the editable connection, target and resource settings in this script.       |
# Access      | HTTPS to vCenter; valid credentials and inventory read access.                     |
# Permissions | Namespaces.SelfServiceManage on the selected cluster.                              |
# Resources   | Ready Supervisor; inactive Namespace Service; existing policy, classes and groups. |
# Local files | Write access to deployment-files beside this script.                               |
#-------------+------------------------------------------------------------------------------------+

# Stop when a command or pipeline fails.
set -eo pipefail

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=labadministrator@vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

CONNECT_TIMEOUT=10
REQUEST_TIMEOUT=120

# Resolve the directory containing this script.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

TEMPLATE_NAME=default
DATACENTER_NAME=platformlab-dc01
CLUSTER_NAME=platformlab-cl01
STORAGE_POLICY_NAME='vSAN Default Storage Policy'

# Set half of the cluster effective CPU capacity measured on 2026-11-07 (136220 MHz).
CPU_LIMIT_MHZ=68110

# Set a 300 GiB memory quota per namespace in MiB.
MEMORY_LIMIT_MIB=307200

# Set a 500 GiB storage quota per namespace and for the assigned storage policy in MiB.
STORAGE_LIMIT_MIB=512000

# Set the VM classes allowed in the namespace as a JSON array.
VM_CLASSES='["best-effort-small","best-effort-medium","best-effort-large","best-effort-xlarge"]'

TEMPLATE_DOMAIN=vsphere.local
TEMPLATE_ADMIN_GROUP=LabAdministrators

# Create the deployment files directory.
mkdir -p ${DEPLOYMENT_FILES}

# Create a vCenter API session.
TOKEN=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -u ${VC_USER}:${VC_PASS} -X POST https://${VCENTER}/api/session | jq -r '.')

# Find the configured datacenter.
DATACENTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/datacenter | jq -r --arg name ${DATACENTER_NAME} '[.[] | select(.name == $name)] | if length == 1 then .[0].datacenter else error("Expected one matching datacenter") end')

# Find the configured cluster in that datacenter.
CLUSTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" "https://${VCENTER}/api/vcenter/cluster?datacenters=${DATACENTER_ID}" | jq -r --arg name ${CLUSTER_NAME} '[.[] | select(.name == $name)] | if length == 1 then .[0].cluster else error("Expected one matching cluster") end')

# Find the configured storage policy.
STORAGE_POLICY_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/storage/policies | jq -r --arg name "${STORAGE_POLICY_NAME}" '[.[] | select(.name == $name)] | if length == 1 then .[0].policy else error("Expected one matching storage policy") end')

# Read the selected Supervisor configuration.
SUPERVISOR_CONFIG=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/namespace-management/clusters/${CLUSTER_ID})

# Resolve the primary workload network for vSphere networking; let NSX manage its own networks.
TEMPLATE_NETWORKS=$(jq -ce '
    if .network_provider == "VSPHERE_NETWORK" then
        [.workload_networks.supervisor_primary_workload_network.network | select(type == "string" and length > 0 and . != "null")]
        | if length == 1 then . else error("Supervisor primary workload network is missing") end
    elif .network_provider == "NSXT_CONTAINER_PLUGIN" or .network_provider == "NSX_VPC" then []
    else error("Unsupported or missing Supervisor network provider") end' <<< "${SUPERVISOR_CONFIG}")

# Build the template quotas, permissions, VM classes and provider-specific network settings.
TEMPLATE_PAYLOAD=$(jq -n --arg template ${TEMPLATE_NAME} --arg policy ${STORAGE_POLICY_ID} \
    --argjson networks "${TEMPLATE_NETWORKS}" --argjson cpu ${CPU_LIMIT_MHZ} --argjson memory ${MEMORY_LIMIT_MIB} \
    --argjson limit ${STORAGE_LIMIT_MIB} --argjson classes "${VM_CLASSES}" \
    --arg domain ${TEMPLATE_DOMAIN} --arg admin_group ${TEMPLATE_ADMIN_GROUP} \
    '{template:$template, resource_spec:{cpu_limit:$cpu, memory_limit:$memory, storage_request_limit:$limit}, storage_specs:[{policy:$policy, limit:$limit}], permissions:[{domain:$domain, subject:$admin_group, subject_type:"GROUP"}], vm_service_spec:{vm_classes:$classes}} + (if $networks | length > 0 then {networks:$networks} else {} end)')

# Print and save the template payload before submitting the activation request.
jq . <<< "${TEMPLATE_PAYLOAD}" | tee ${DEPLOYMENT_FILES}/namespace-template-${TEMPLATE_NAME}.json

# Create or update the template and activate Namespace Service on the selected Supervisor.
curl --fail-with-body -kSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -H 'Content-Type: application/json' \
    -X POST "https://${VCENTER}/api/vcenter/namespaces/namespace-self-service/${CLUSTER_ID}?action=activateWithTemplate" \
    --data @${DEPLOYMENT_FILES}/namespace-template-${TEMPLATE_NAME}.json

# Close the vCenter API session.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/session

# Report acceptance of the template and service activation request.
echo "Namespace template and service activation request accepted: ${TEMPLATE_NAME}"
