#!/usr/bin/env bash
#---------------+------------------------------------------------------------------------------------+
# Script Name   | 01-create-vcenter-users.sh                                                         |
# Updated       | 2026-11-15                                                                         |
# Version       | 1.22                                                                               |
# VCF Version   | 9.1.1                                                                              |
# Description   | Create SSO users and groups; assign vCenter and Supervisor permissions.            |
#---------------+------------------------------------------------------------------------------------+

#---------------+------------------------------------------------------------------------------------+
# Requirement   | Details                                                                            |
#---------------+------------------------------------------------------------------------------------+
# Runtime       | Bash 3.2+ on macOS or Linux.                                                       |
# Tools         | govc and awk available in PATH.                                                    |
# Access        | HTTPS access to vCenter 9.1.1 with SSO administrator credentials.                  |
# Configuration | Set connection, SSO user/group names and Supervisor folder path.                   |
# Local files   | Write access to the govc session cache.                                            |
# Targets       | Existing Supervisor folder, roles and built-in SSO groups.                         |
# Changes       | Creates lab users/groups and grants administrator access.                          |
#---------------+------------------------------------------------------------------------------------+

# Stop when a command fails.
set -e

VCENTER=mgmt-vcsa.platformlab.vcf
VC_USER=administrator@vsphere.local
SSO_DOMAIN=vsphere.local
VC_PASS='VMwar3!!VMwar3!!'

LAB_USER=labuser
LAB_USER_PASSWORD="${VC_PASS}"
LAB_USER_GROUP=LabUsers

LAB_ADMIN=labadministrator
LAB_ADMIN_PASSWORD="${VC_PASS}"
LAB_ADMIN_GROUP=LabAdministrators
LAB_ADMIN_ROLE=Admin
LAB_ADMIN_SUPERVISOR_ROLES=(
    SupervisorAdministrator
    SupervisorProviderAdministrator
)
SSO_ADMIN_GROUP=Administrators
SSO_PROVIDER_GROUP=SupervisorProviderAdministrators

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

# Connect to vCenter; the SSO commands below use the SSO administration API, not REST.
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

# List existing SSO groups; stop if the lookup fails.
echo "+ govc sso.group.ls"
SSO_GROUPS=$(govc sso.group.ls)

# Create labusers only when the group does not exist.
echo "Checking whether ${LAB_USER_GROUP} is present in the retrieved list..."
if ! awk -v name=${LAB_USER_GROUP} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_GROUPS}"; then
    echo "+ govc sso.group.create ${LAB_USER_GROUP}"
    govc sso.group.create ${LAB_USER_GROUP}
fi

# Create labadministrators only when the group does not exist.
echo "Checking whether ${LAB_ADMIN_GROUP} is present in the retrieved list..."
if ! awk -v name=${LAB_ADMIN_GROUP} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_GROUPS}"; then
    echo "+ govc sso.group.create ${LAB_ADMIN_GROUP}"
    govc sso.group.create ${LAB_ADMIN_GROUP}
fi

# List existing SSO users; stop if the lookup fails.
echo "+ govc sso.user.ls"
SSO_USERS=$(govc sso.user.ls)

# Create labuser only when the account does not exist; retain its existing password.
echo "Checking whether ${LAB_USER} is present in the retrieved list..."
if ! awk -v name=${LAB_USER} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_USERS}"; then
    echo "+ govc sso.user.create -p [REDACTED] ${LAB_USER}"
    govc sso.user.create -p "${LAB_USER_PASSWORD}" ${LAB_USER}
fi

# Create labadministrator only when the account does not exist; retain its existing password.
echo "Checking whether ${LAB_ADMIN} is present in the retrieved list..."
if ! awk -v name=${LAB_ADMIN} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_USERS}"; then
    echo "+ govc sso.user.create -p [REDACTED] ${LAB_ADMIN}"
    govc sso.user.create -p "${LAB_ADMIN_PASSWORD}" ${LAB_ADMIN}
fi

# List current labusers members; stop if the lookup fails.
echo "+ govc sso.user.ls -group ${LAB_USER_GROUP}"
LAB_USER_MEMBERS=$(govc sso.user.ls -group ${LAB_USER_GROUP})

# Add labuser only when it is not already a member of labusers.
echo "Checking whether ${LAB_USER} is present in the retrieved list..."
if ! awk -v name=${LAB_USER} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${LAB_USER_MEMBERS}"; then
    echo "+ govc sso.group.update -a ${LAB_USER} ${LAB_USER_GROUP}"
    govc sso.group.update -a ${LAB_USER} ${LAB_USER_GROUP}
fi

# List current labadministrators members; stop if the lookup fails.
echo "+ govc sso.user.ls -group ${LAB_ADMIN_GROUP}"
LAB_ADMIN_MEMBERS=$(govc sso.user.ls -group ${LAB_ADMIN_GROUP})

# Add labadministrator only when it is not already a member of labadministrators.
echo "Checking whether ${LAB_ADMIN} is present in the retrieved list..."
if ! awk -v name=${LAB_ADMIN} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${LAB_ADMIN_MEMBERS}"; then
    echo "+ govc sso.group.update -a ${LAB_ADMIN} ${LAB_ADMIN_GROUP}"
    govc sso.group.update -a ${LAB_ADMIN} ${LAB_ADMIN_GROUP}
fi

# Assign Supervisor Administrator first, before root Administrator can inherit onto this folder.
echo "+ govc permissions.set -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} -role ${LAB_ADMIN_SUPERVISOR_ROLES[0]} -propagate=true ${SUPERVISOR_FOLDER}"
govc permissions.set -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} \
    -role ${LAB_ADMIN_SUPERVISOR_ROLES[0]} -propagate=true ${SUPERVISOR_FOLDER}

# Assign root Administrator after the explicit Supervisor permission is established.
echo "+ govc permissions.set -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} -role ${LAB_ADMIN_ROLE} -propagate=true /"
govc permissions.set -group=true -principal ${LAB_ADMIN_GROUP}@${SSO_DOMAIN} \
    -role ${LAB_ADMIN_ROLE} -propagate=true /

# Use the existing SSO group already assigned Supervisor Provider Administrator.
echo "Using ${LAB_ADMIN_SUPERVISOR_ROLES[1]} through ${SSO_PROVIDER_GROUP} membership."
echo "+ govc sso.user.ls -group ${SSO_PROVIDER_GROUP}"
SSO_PROVIDER_MEMBERS=$(govc sso.user.ls -group ${SSO_PROVIDER_GROUP})

# Add the lab administrator to the existing Provider group when membership is missing.
echo "Checking whether ${LAB_ADMIN} belongs to ${SSO_PROVIDER_GROUP}..."
if ! awk -v name=${LAB_ADMIN} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_PROVIDER_MEMBERS}"; then
    echo "+ govc sso.group.update -a ${LAB_ADMIN} ${SSO_PROVIDER_GROUP}"
    govc sso.group.update -a ${LAB_ADMIN} ${SSO_PROVIDER_GROUP}
fi

# List current SSO Administrators members; stop if the lookup fails.
echo "+ govc sso.user.ls -group ${SSO_ADMIN_GROUP}"
SSO_ADMIN_MEMBERS=$(govc sso.user.ls -group ${SSO_ADMIN_GROUP})

# Add labadministrator directly to Administrators only when membership is missing.
echo "Checking whether ${LAB_ADMIN} is present in the retrieved list..."
if ! awk -v name=${LAB_ADMIN} 'tolower($1) == tolower(name) {found=1} END {exit !found}' <<< "${SSO_ADMIN_MEMBERS}"; then
    echo "+ govc sso.group.update -a ${LAB_ADMIN} ${SSO_ADMIN_GROUP}"
    govc sso.group.update -a ${LAB_ADMIN} ${SSO_ADMIN_GROUP}
fi

# Close the vCenter session.
echo "+ govc session.logout"
govc session.logout

# Report that the SSO commands completed.
echo 'SSO users, groups and memberships configured; Administrator and Supervisor access assigned.'
