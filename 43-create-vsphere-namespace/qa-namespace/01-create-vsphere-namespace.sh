#!/usr/bin/env bash
#-------------+------------------------------------------------------------------------------------------------+
# Script Name | 01-create-vsphere-namespace.sh                                                                 |
# Updated     | 2026-11-15                                                                                     |
# Version     | 4.22                                                                                           |
# VCF Version | 9.1.1.0-545627-2026-09                                                                         |
# Description | Create one namespace using the existing standard Supervisor library.                           |
#-------------+------------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                        |
#-------------+------------------------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                                   |
# Tools       | curl and jq; tee for saved JSON.                                                               |
# Inputs      | Review the editable connection, target and resource settings in this script.                   |
# Access      | HTTPS to vCenter; valid credentials and namespace management permissions.                      |
# Resources   | Existing Supervisor-enabled cluster, storage policy, VM classes and access group.              |
# Local files | Write access to the configured deployment-files directory.                                     |
#-------------+------------------------------------------------------------------------------------------------+

# Namespace permission model (domain: vsphere.local).
# The Supervisor role is configured separately; this file assigns read-only namespace access.
#-------------------+--------------------------+---------------------------------------------------------------+
# Group             | Role                     | Assigned at                                                   |
#-------------------+--------------------------+---------------------------------------------------------------+
# LabUsers          | Namespaces View (VIEW)   | DEV/QA namespace                                              |
# LabAdministrators | Supervisor Administrator | Supervisor: lab-supervisor                                    |
#-------------------+--------------------------+---------------------------------------------------------------+

# Stop when a command fails.
set -e

# Resolve the directory containing this script.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=labadministrator@vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

CONNECT_TIMEOUT=10
REQUEST_TIMEOUT=120
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

NAMESPACE_NAME=qa-namespace
NAMESPACE_DESCRIPTION=qa-namespace
NAMESPACE_DOMAIN=vsphere.local
NAMESPACE_GROUP=LabUsers
NAMESPACE_ROLE=VIEW
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

# Create a vCenter API session.
TOKEN=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -u ${VC_USER}:${VC_PASS} -X POST https://${VCENTER}/api/session | jq -r '.')

# Find the configured datacenter.
DATACENTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/datacenter | jq -r --arg name ${DATACENTER_NAME} '.[] | select(.name == $name) | .datacenter')

# Find the configured cluster in that datacenter.
CLUSTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" "https://${VCENTER}/api/vcenter/cluster?datacenters=${DATACENTER_ID}" | jq -r --arg name ${CLUSTER_NAME} '.[] | select(.name == $name) | .cluster')

# Find the configured storage policy.
STORAGE_POLICY_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/storage/policies | jq -r --arg name "${STORAGE_POLICY_NAME}" '.[] | select(.name == $name) | .policy')

# Build the namespace access, storage and VM service settings.
NAMESPACE_SPEC=$(jq -n --arg cluster ${CLUSTER_ID} --arg policy ${STORAGE_POLICY_ID} --argjson limit ${STORAGE_LIMIT_MIB} \
    --argjson cpu ${CPU_LIMIT_MHZ} --argjson memory ${MEMORY_LIMIT_MIB} --argjson classes "${VM_CLASSES}" \
    --arg domain ${NAMESPACE_DOMAIN} --arg group ${NAMESPACE_GROUP} --arg role ${NAMESPACE_ROLE} \
    '{cluster:$cluster, access_list:[{domain:$domain, subject:$group, subject_type:"GROUP", role:$role}], resource_spec:{cpu_limit:$cpu, memory_limit:$memory, storage_request_limit:$limit}, storage_specs:[{policy:$policy, limit:$limit}], vm_service_spec:{vm_classes:$classes}}')

# Add the namespace name and description.
NAMESPACE_PAYLOAD=$(jq --arg name ${NAMESPACE_NAME} --arg description "${NAMESPACE_DESCRIPTION}" '. + {namespace:$name, description:$description}' <<< "${NAMESPACE_SPEC}")

# Create the deployment files directory.
mkdir -p ${DEPLOYMENT_FILES}

# Print and save the namespace payload before submitting the creation request.
jq . <<< "${NAMESPACE_PAYLOAD}" | tee ${DEPLOYMENT_FILES}/${NAMESPACE_NAME}.json

# Submit the namespace creation request.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} -H "vmware-api-session-id: ${TOKEN}" \
    -H 'Content-Type: application/json' -X POST https://${VCENTER}/api/vcenter/namespaces/instances --data "${NAMESPACE_PAYLOAD}"

# Close the vCenter API session.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/session

# Report acceptance of the namespace creation request.
echo "Namespace creation request accepted: ${NAMESPACE_NAME}"
