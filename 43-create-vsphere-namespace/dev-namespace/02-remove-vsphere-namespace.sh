#!/usr/bin/env bash
#-------------+------------------------------------------------------------------------------------------------+
# Script Name | 02-remove-vsphere-namespace.sh                                                                 |
# Updated     | 2026-11-15                                                                                     |
# Version     | 4.12                                                                                           |
# VCF Version | 9.1.1.0-545627-2026-09                                                                         |
# Description | Submit deletion of one namespace and its workloads.                                            |
#-------------+------------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                        |
#-------------+------------------------------------------------------------------------------------------------+
# Runtime     | Bash 3.2+ on macOS or Linux.                                                                   |
# Tools       | curl and jq.                                                                                   |
# Inputs      | Review the editable connection, target and resource settings in this script.                   |
# Access      | HTTPS to vCenter; valid credentials and namespace management permissions.                      |
# Effect      | Deletes the selected namespace and its workloads without a confirmation prompt.                |
#-------------+------------------------------------------------------------------------------------------------+

# Stop when a command fails.
set -e

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=labadministrator@vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

CONNECT_TIMEOUT=10
REQUEST_TIMEOUT=120

NAMESPACE_NAME=dev-namespace

# Create a vCenter API session.
TOKEN=$(curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -u ${VC_USER}:${VC_PASS} -X POST https://${VCENTER}/api/session | jq -r '.')

# Submit deletion of the namespace and its workloads.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/vcenter/namespaces/instances/${NAMESPACE_NAME}

# Close the vCenter API session.
curl -fkSs --connect-timeout ${CONNECT_TIMEOUT} --max-time ${REQUEST_TIMEOUT} \
    -H "vmware-api-session-id: ${TOKEN}" -X DELETE https://${VCENTER}/api/session

# Report request acceptance without claiming namespace removal is complete.
echo "Namespace deletion request accepted: ${NAMESPACE_NAME}; removal has not been checked."
