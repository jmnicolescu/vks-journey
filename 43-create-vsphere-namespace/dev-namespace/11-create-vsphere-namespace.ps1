#Requires -Version 7.0
#-------------+------------------------------------------------------------------------------------------------+
# Script Name | 11-create-vsphere-namespace.ps1                                                                |
# Updated     | 2026-11-15                                                                                     |
# Version     | 1.12                                                                                           |
# VCF Version | 9.1.1.0-545627-2026-09                                                                         |
# Description | Create one namespace using the existing standard Supervisor library.                           |
#-------------+------------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                        |
#-------------+------------------------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.4+ for REST timeout parameters.                                                   |
# Tools       | Native PowerShell HTTP and JSON commands.                                                      |
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
$ErrorActionPreference = 'Stop'

$VCENTER = 'mgmt-vcsa.platformlab.vcf'
$VC_USER = 'labadministrator@vsphere.local'
$VC_PASS = 'VMwar3!!VMwar3!!'

$CONNECT_TIMEOUT = 10
$REQUEST_TIMEOUT = 120
$DEPLOYMENT_FILES = "$PSScriptRoot/deployment-files"

$NAMESPACE_NAME = 'dev-namespace'
$NAMESPACE_DESCRIPTION = 'dev-namespace'
$NAMESPACE_DOMAIN = 'vsphere.local'
$NAMESPACE_GROUP = 'LabUsers'
$NAMESPACE_ROLE = 'VIEW'
$DATACENTER_NAME = 'platformlab-dc01'
$CLUSTER_NAME = 'platformlab-cl01'
$STORAGE_POLICY_NAME = 'vSAN Default Storage Policy'

# Set half of the cluster effective CPU capacity measured on 2026-11-07 (136220 MHz).
$CPU_LIMIT_MHZ = 68110

# Set a 300 GiB memory quota per namespace in MiB.
$MEMORY_LIMIT_MIB = 307200

# Set a 500 GiB storage quota per namespace and for the assigned storage policy in MiB.
$STORAGE_LIMIT_MIB = 512000

# Set the VM classes allowed in the namespace.
$VM_CLASSES = @('best-effort-small', 'best-effort-medium', 'best-effort-large', 'best-effort-xlarge')

# Convert the configured password for native PowerShell authentication.
$SECURE_PASSWORD = ConvertTo-SecureString $VC_PASS -AsPlainText -Force

# Create the vCenter credential.
$CREDENTIAL = [pscredential]::new($VC_USER, $SECURE_PASSWORD)

# Create a vCenter API session.
$TOKEN = Invoke-RestMethod -Method Post -Uri "https://$VCENTER/api/session" `
    -Authentication Basic -Credential $CREDENTIAL -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Set the session header for subsequent requests.
$HEADERS = @{ 'vmware-api-session-id' = $TOKEN }

# Read datacenter inventory.
$DATACENTERS = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/datacenter" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Find the configured datacenter.
$DATACENTER_ID = ($DATACENTERS | Where-Object name -eq $DATACENTER_NAME).datacenter

# Read cluster inventory in the configured datacenter.
$CLUSTERS = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/cluster?datacenters=$DATACENTER_ID" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Find the configured cluster.
$CLUSTER_ID = ($CLUSTERS | Where-Object name -eq $CLUSTER_NAME).cluster

# Read storage policy inventory.
$STORAGE_POLICIES = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/storage/policies" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Find the configured storage policy.
$STORAGE_POLICY_ID = ($STORAGE_POLICIES | Where-Object name -eq $STORAGE_POLICY_NAME).policy

# Build the namespace payload with access, storage and VM service settings.
$NAMESPACE_PAYLOAD = [ordered]@{
    cluster = $CLUSTER_ID
    namespace = $NAMESPACE_NAME
    description = $NAMESPACE_DESCRIPTION
    access_list = @(@{ domain = $NAMESPACE_DOMAIN; subject = $NAMESPACE_GROUP; subject_type = 'GROUP'; role = $NAMESPACE_ROLE })
    resource_spec = @{ cpu_limit = $CPU_LIMIT_MHZ; memory_limit = $MEMORY_LIMIT_MIB; storage_request_limit = $STORAGE_LIMIT_MIB }
    storage_specs = @(@{ policy = $STORAGE_POLICY_ID; limit = $STORAGE_LIMIT_MIB })
    vm_service_spec = @{ vm_classes = $VM_CLASSES }
} | ConvertTo-Json -Depth 10

# Create the deployment files directory.
New-Item -ItemType Directory -Path $DEPLOYMENT_FILES -Force | Out-Null

# Print and save the namespace payload before submitting the creation request.
$NAMESPACE_PAYLOAD | Tee-Object -FilePath "$DEPLOYMENT_FILES/$NAMESPACE_NAME.json"

# Submit the namespace creation request.
Invoke-RestMethod -Method Post -Uri "https://$VCENTER/api/vcenter/namespaces/instances" `
    -Headers $HEADERS -ContentType 'application/json' -Body $NAMESPACE_PAYLOAD -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Close the vCenter API session.
Invoke-RestMethod -Method Delete -Uri "https://$VCENTER/api/session" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Report acceptance of the namespace creation request.
Write-Output "Namespace creation request accepted: $NAMESPACE_NAME"
