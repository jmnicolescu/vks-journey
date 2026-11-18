#!/usr/bin/env bash
#---------------+------------------------------------------------------------------------------------+
# Script Name   | 02-delete-vcenter-users.sh                                                         |
# Updated       | 2026-11-15                                                                         |
# Version       | 1.12                                                                               |
# VCF Version   | 9.1.1                                                                              |
# Description   | Remove lab permissions, the custom Supervisor role, SSO users and groups.          |
#---------------+------------------------------------------------------------------------------------+

#---------------+------------------------------------------------------------------------------------+
# Requirement   | Details                                                                            |
#---------------+------------------------------------------------------------------------------------+
# Runtime       | Bash 3.2+ on macOS or Linux.                                                       |
# Tools         | govc and awk available in PATH.                                                    |
# Access        | HTTPS access to vCenter 9.1.1 with SSO administrator credentials.                  |
# Configuration | Set connection, SSO user/group names and Supervisor folder path.                   |
# Local files   | Write access to the govc session cache.                                            |
# Targets       | Configured lab users/groups, Supervisor folder and legacy custom role.             |
# Changes       | Deletes lab permissions, users/groups and the legacy custom role if present.       |
#---------------+------------------------------------------------------------------------------------+

# Stop when a command fails.
# set -e

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=administrator@vsphere.local
SSO_DOMAIN=vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

LAB_USER=labuser
LAB_USER_GROUP=LabUsers
LAB_ADMIN=labadministrator
LAB_ADMIN_GROUP=LabAdministrators
LAB_ADMIN_COMBINED_ROLE=LabSupervisorAdministrator

SUPERVISOR_FOLDER=/platformlab-dc01/vm/Namespaces/lab-supervisor

# Exit if the govc utility is not installed.
echo "Checking that govc is installed..."
if ! command -v govc >/dev/null 2>&1; then
    echo 'Error: govc is not installed or is not in PATH.' >&2
    exit 1
fi

# Configure govc authentication and allow the lab vCenter certificate.
echo "Configuring govc for ${VCENTER} as ${VC_USER} (password hidden)..."
export GOVC_URL=https://${VCENTER} GOVC_USERNAME=${VC_USER} GOVC_PASSWORD="${VC_PASS}" GOVC_INSECURE=true GOVC_PERSIST_SESSION=true

# Connect to vCenter; deletion uses the SSO administration API, not REST.
echo "+ govc session.login -issue (SSO token hidden)"
SSO_TOKEN=$(govc session.login -issue)

# End the cached session so token login cannot reuse password authentication.
echo "+ govc session.logout (discard cached session before token login)"
govc session.logout

# Use token authentication for Supervisor permission operations.
echo "+ govc session.login -token [REDACTED]"
govc session.login -token "${SSO_TOKEN}"

# Remove the token from the shell after the authenticated session is cached.
echo "Clearing the SSO token variable..."
unset SSO_TOKEN

# Remove the direct LabUsers permission from the Supervisor folder, if present.
echo "+ govc permissions.remove -f=true -group=true -principal ${LAB_USER_GROUP}@${SSO_DOMAIN} ${SUPERVISOR_FOLDER}"
govc permissions.remove -f=true -group=true -principal ${LAB_USER_GROUP}@${SSO_DOMAIN} \
    ${SUPERVISOR_FOLDER}

# Remove the Supervisor role assignment from LabAdministrators, if present.
echo "+ govc permissions.remove -f=true -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} ${SUPERVISOR_FOLDER}"
govc permissions.remove -f=true -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} \
    ${SUPERVISOR_FOLDER}

# Remove the direct Supervisor Provider role assignment from labadministrator, if present.
echo "+ govc permissions.remove -f=true -group=false -principal ${LAB_ADMIN}@${SSO_DOMAIN} ${SUPERVISOR_FOLDER}"
govc permissions.remove -f=true -group=false -principal ${LAB_ADMIN}@${SSO_DOMAIN} \
    ${SUPERVISOR_FOLDER}

# Remove the root Administrator role assignment from LabAdministrators, if present.
echo "+ govc permissions.remove -f=true -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} /"
govc permissions.remove -f=true -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} /

# List roles to check for the custom role left by earlier versions of script 01.
echo "+ govc role.ls"
VC_ROLES=$(govc role.ls)

# Delete the legacy custom lab role if present; stop if it is still assigned elsewhere.
echo "Checking whether ${LAB_ADMIN_COMBINED_ROLE} is present in the retrieved list..."
if awk -v name=${LAB_ADMIN_COMBINED_ROLE} '$1 == name {found=1} END {exit !found}' <<< "${VC_ROLES}"; then
    echo "+ govc role.remove ${LAB_ADMIN_COMBINED_ROLE}"
    govc role.remove ${LAB_ADMIN_COMBINED_ROLE}
fi

# Delete the labuser SSO account.
echo "+ govc sso.user.rm ${LAB_USER}"
govc sso.user.rm ${LAB_USER}

# Delete the labadministrator SSO account.
echo "+ govc sso.user.rm ${LAB_ADMIN}"
govc sso.user.rm ${LAB_ADMIN}

# Delete the LabUsers SSO group.
echo "+ govc sso.group.rm ${LAB_USER_GROUP}"
govc sso.group.rm ${LAB_USER_GROUP}

# Delete the LabAdministrators SSO group.
echo "+ govc sso.group.rm ${LAB_ADMIN_GROUP}"
govc sso.group.rm ${LAB_ADMIN_GROUP}

# Close the vCenter session.
echo "+ govc session.logout"
govc session.logout

# Report that the lab cleanup commands completed.
echo 'Lab permissions, custom Supervisor role, SSO users and groups deleted.'
