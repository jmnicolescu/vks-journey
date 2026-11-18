#!/usr/bin/env bash
#-------------+------------------------------------------------------------------------------------------+
# Script Name | 31-deactivate-namespace-template.sh                                                      |
# Updated     | 2026-11-15                                                                               |
# Version     | 1.8                                                                                      |
# VCF Version | 9.1.1.0-545627-2026-09                                                                   |
# Description | Deactivate Namespace Service to stop use of the self-service namespace template.         |
#-------------+------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                  |
#-------------+------------------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                             |
# Tools       | curl and jq.                                                                             |
# Inputs      | Review the connection and target settings in this script.                                |
# Access      | HTTPS to vCenter; valid credentials and inventory read access.                           |
# Permissions | Namespaces.SelfServiceManage on the selected cluster.                                    |
# Resources   | Existing Supervisor with active Namespace Service.                                       |
# Effect      | Stops new self-service creation; retains existing namespaces and template configuration. |
#-------------+------------------------------------------------------------------------------------------+

# Stop when a command fails.
set -e

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=labadministrator@vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

CONNECT_TIMEOUT=10
REQUEST_TIMEOUT=120
DEPLOYMENT_FILES=deployment-files

DATACENTER_NAME=platformlab-dc01
CLUSTER_NAME=platformlab-cl01

# Create a vCenter API session.
TOKEN=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -u ${VC_USER}:${VC_PASS} -X POST https://${VCENTER}/api/session | jq -r '.')

# Find the configured datacenter.
DATACENTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" https://${VCENTER}/api/vcenter/datacenter | jq -r --arg name ${DATACENTER_NAME} '.[] | select(.name == $name) | .datacenter')

# Find the configured cluster in that datacenter.
CLUSTER_ID=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" "https://${VCENTER}/api/vcenter/cluster?datacenters=${DATACENTER_ID}" | jq -r --arg name ${CLUSTER_NAME} '.[] | select(.name == $name) | .cluster')

# Deactivate Namespace Service; the template configuration and existing namespaces are retained.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" \
    -X POST "https://${VCENTER}/api/vcenter/namespaces/namespace-self-service/${CLUSTER_ID}?action=deactivate"

# Close the vCenter API session.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/session

# Report acceptance of the Namespace Service deactivation request.
echo "Namespace Service deactivation request accepted: ${CLUSTER_NAME}"
