#!/usr/bin/env bash
#---------------+----------------------------------------------------------------------------+
# Script Name   | 01-get-supervisor-endpoint.sh                                              |
# Updated       | 2026-11-15                                                                 |
# Version       | 1.7                                                                        |
# VCF Version   | 9.1.1.0-545627-2026-09                                                     |
# Description   | Retrieve the Supervisor API endpoint and save it in shell profiles.        |
#---------------+----------------------------------------------------------------------------+

#---------------+----------------------------------------------------------------------------+
# Requirement   | Details                                                                    |
#---------------+----------------------------------------------------------------------------+
# Runtime       | Bash 3.2 or newer on macOS or Linux.                                       |
# Tools         | curl, jq, uname, grep, sed and touch.                                      |
# Access        | vCenter HTTPS access, valid credentials and Supervisor read permissions.   |
# Configuration | Set VCENTER, VC_USER, VC_PASS and CLUSTER_NAME in this script.             |
# Profiles      | Write ~/.zshrc on macOS; ~/.bash_profile and ~/.profile on Linux.          |
# Environment   | Reload the updated profile in the shell that will use the endpoint.        |
# TLS           | curl -k bypasses vCenter certificate validation for lab use.               |
#---------------+----------------------------------------------------------------------------+

set -euo pipefail

VCENTER='mgmt-vcsa.platformlab.vcf'
VC_USER='labadministrator@vsphere.local'
VC_PASS='VMwar3!!VMwar3!!'
CLUSTER_NAME='platformlab-cl01'

CURL_OPTIONS=(-fsS --connect-timeout 10 --max-time 30)
# For an untrusted lab certificate, add: CURL_OPTIONS+=(-k)

command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }

SESSION_ID=$(curl -fsSk -X POST -u "${VC_USER}:${VC_PASS}" https://${VCENTER}/api/session | jq -r '.')

# automatically log out of vCenter when the script exits,
trap 'curl -sk -X DELETE -H "vmware-api-session-id: ${SESSION_ID}" https://${VCENTER}/api/session >/dev/null' EXIT

CLUSTER_ID=$(curl -fsSk -G -H "vmware-api-session-id: ${SESSION_ID}" \
  --data-urlencode "names=${CLUSTER_NAME}" \
  https://${VCENTER}/api/vcenter/cluster | jq -r '.[0].cluster')

SUPERVISOR_NAME=$(curl -fsSk \
  -H "vmware-api-session-id: ${SESSION_ID}" \
  https://${VCENTER}/api/vcenter/namespace-management/supervisors/summaries \
  | jq -r '.items[0].info.name')

SUPERVISOR_ENDPOINT=$(curl -fsSk \
  -H "vmware-api-session-id: ${SESSION_ID}" \
  https://${VCENTER}/api/vcenter/namespace-management/clusters/${CLUSTER_ID} | jq -er '.api_server_cluster_endpoint | select(. != null and . != "")')

echo "Supervisor:   ${SUPERVISOR_NAME}"
echo "Cluster:      ${CLUSTER_NAME}"
echo "API endpoint: ${SUPERVISOR_ENDPOINT}"

# Select the shell profiles and platform-specific sed options.
case $(uname -s) in
    Darwin) PROFILE_FILES=("${HOME}/.zshrc"); SED_OPTIONS=(-i '') ;;
    Linux) PROFILE_FILES=("${HOME}/.bash_profile" "${HOME}/.profile"); SED_OPTIONS=(-i) ;;
    *) exit 0 ;;
esac

# Replace the endpoint export, or append it when it is missing.
for PROFILE_FILE in "${PROFILE_FILES[@]}"; do
    # Create the profile if it does not exist.
    touch "${PROFILE_FILE}"

    # Update the existing export or add the new endpoint.
    if grep -qE '^[[:space:]]*export[[:space:]]+SUPERVISOR_API_ENDPOINT=' "${PROFILE_FILE}"; then
        sed "${SED_OPTIONS[@]}" -E \
            "s|^[[:space:]]*export[[:space:]]+SUPERVISOR_API_ENDPOINT=.*|export SUPERVISOR_API_ENDPOINT=${SUPERVISOR_ENDPOINT}|" "${PROFILE_FILE}"
    else
        printf '\nexport SUPERVISOR_API_ENDPOINT=%s\n' "${SUPERVISOR_ENDPOINT}" >> "${PROFILE_FILE}"
    fi

    # Show which profile was updated.
    echo "Updated: ${PROFILE_FILE}"
done
