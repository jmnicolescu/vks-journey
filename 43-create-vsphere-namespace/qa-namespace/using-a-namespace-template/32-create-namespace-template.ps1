#Requires -Version 7.4
#-------------+------------------------------------------------------------------------------------+
# Script Name | 32-create-namespace-template.ps1                                                   |
# Updated     | 2026-11-15                                                                         |
# Version     | 1.13                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                             |
# Description | Configure a self-service namespace template and activate Namespace Service.        |
#-------------+------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------+
# Requirement | Details                                                                            |
#-------------+------------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.4+ for REST timeout parameters.                                       |
# Tools       | Native PowerShell HTTP and JSON commands.                                          |
# Inputs      | Review the editable connection, target and resource settings in this script.       |
# Access      | HTTPS to vCenter; valid credentials and inventory read access.                     |
# Permissions | Namespaces.SelfServiceManage on the selected cluster.                              |
# Resources   | Ready Supervisor; inactive Namespace Service; existing policy, classes and groups. |
# Local files | Write access to deployment-files beside this script.                               |
#-------------+------------------------------------------------------------------------------------+

# Stop when a command fails.
$ErrorActionPreference = 'Stop'

$VCENTER = 'mgmt-vcsa.platformlab.vcf'
$VC_USER = 'labadministrator@vsphere.local'
$VC_PASS = 'VMwar3!!VMwar3!!'

$CONNECT_TIMEOUT = 10
$REQUEST_TIMEOUT = 120
$DEPLOYMENT_FILES = "$PSScriptRoot/deployment-files"

$TEMPLATE_NAME = 'default'
$DATACENTER_NAME = 'platformlab-dc01'
$CLUSTER_NAME = 'platformlab-cl01'
$STORAGE_POLICY_NAME = 'vSAN Default Storage Policy'

# Set half of the cluster effective CPU capacity measured on 2026-11-07 (136220 MHz).
$CPU_LIMIT_MHZ = 68110

# Set a 300 GiB memory quota per namespace in MiB.
$MEMORY_LIMIT_MIB = 307200

# Set a 500 GiB storage quota per namespace and for the assigned storage policy in MiB.
$STORAGE_LIMIT_MIB = 512000

# Set the VM classes allowed in namespaces created from this template.
$VM_CLASSES = @('best-effort-small', 'best-effort-medium', 'best-effort-large', 'best-effort-xlarge')

$TEMPLATE_DOMAIN = 'vsphere.local'
$TEMPLATE_ADMIN_GROUP = 'LabAdministrators'

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
$MATCHES_FOUND = @($DATACENTERS | Where-Object name -eq $DATACENTER_NAME)

# Require exactly one matching datacenter.
if ($MATCHES_FOUND.Count -ne 1) { throw 'Expected one matching datacenter' }

# Use the resolved datacenter identifier.
$DATACENTER_ID = $MATCHES_FOUND[0].datacenter

# Read cluster inventory in the configured datacenter.
$CLUSTERS = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/cluster?datacenters=$DATACENTER_ID" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Find the configured cluster.
$MATCHES_FOUND = @($CLUSTERS | Where-Object name -eq $CLUSTER_NAME)

# Require exactly one matching cluster.
if ($MATCHES_FOUND.Count -ne 1) { throw 'Expected one matching cluster' }

# Use the resolved cluster identifier.
$CLUSTER_ID = $MATCHES_FOUND[0].cluster

# Read storage policy inventory.
$STORAGE_POLICIES = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/storage/policies" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Find the configured storage policy.
$MATCHES_FOUND = @($STORAGE_POLICIES | Where-Object name -eq $STORAGE_POLICY_NAME)

# Require exactly one matching storage policy.
if ($MATCHES_FOUND.Count -ne 1) { throw 'Expected one matching storage policy' }

# Use the resolved storage policy identifier.
$STORAGE_POLICY_ID = $MATCHES_FOUND[0].policy

# Read the Supervisor configuration for the selected cluster.
$SUPERVISOR = Invoke-RestMethod -Method Get -Uri "https://$VCENTER/api/vcenter/namespace-management/clusters/$CLUSTER_ID" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Resolve the primary workload network for vSphere networking; let NSX manage its own networks.
$TEMPLATE_NETWORKS = @()
if ($SUPERVISOR.network_provider -eq 'VSPHERE_NETWORK') {
    # Read the Supervisor primary workload network.
    $WORKLOAD_NETWORK = $SUPERVISOR.workload_networks.supervisor_primary_workload_network.network

    # Require a valid primary workload network before submitting the template.
    if ($WORKLOAD_NETWORK -isnot [string] -or [string]::IsNullOrWhiteSpace($WORKLOAD_NETWORK) -or $WORKLOAD_NETWORK -eq 'null') {
        throw 'Supervisor primary workload network is missing'
    }

    # Associate the template with the resolved vSphere workload network.
    $TEMPLATE_NETWORKS = @($WORKLOAD_NETWORK)
} elseif ($SUPERVISOR.network_provider -notin @('NSXT_CONTAINER_PLUGIN', 'NSX_VPC')) {
    throw 'Unsupported or missing Supervisor network provider'
}

# Build the template quotas, permissions and VM classes.
$TEMPLATE_PAYLOAD = [ordered]@{
    template = $TEMPLATE_NAME
    resource_spec = @{
        cpu_limit = $CPU_LIMIT_MHZ
        memory_limit = $MEMORY_LIMIT_MIB
        storage_request_limit = $STORAGE_LIMIT_MIB
    }
    storage_specs = @(@{ policy = $STORAGE_POLICY_ID; limit = $STORAGE_LIMIT_MIB })
    permissions = @(
        @{ domain = $TEMPLATE_DOMAIN; subject = $TEMPLATE_ADMIN_GROUP; subject_type = 'GROUP' }
    )
    vm_service_spec = @{ vm_classes = $VM_CLASSES }
}

# Include the workload network only for a vSphere networking Supervisor.
if ($TEMPLATE_NETWORKS.Count -gt 0) { $TEMPLATE_PAYLOAD.networks = $TEMPLATE_NETWORKS }

# Convert the template payload to JSON.
$TEMPLATE_PAYLOAD = $TEMPLATE_PAYLOAD | ConvertTo-Json -Depth 10

# Create the deployment files directory.
New-Item -ItemType Directory -Path $DEPLOYMENT_FILES -Force | Out-Null

# Print and save the template payload before submitting the activation request.
$TEMPLATE_PAYLOAD | Tee-Object -FilePath "$DEPLOYMENT_FILES/namespace-template-$TEMPLATE_NAME.json"

# Create or update the template and activate Namespace Service on the selected Supervisor.
Invoke-RestMethod -Method Post -Uri "https://$VCENTER/api/vcenter/namespaces/namespace-self-service/$($CLUSTER_ID)?action=activateWithTemplate" `
    -Headers $HEADERS -ContentType 'application/json' -InFile "$DEPLOYMENT_FILES/namespace-template-$TEMPLATE_NAME.json" -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Close the vCenter API session.
Invoke-RestMethod -Method Delete -Uri "https://$VCENTER/api/session" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Report acceptance of the template and service activation request.
Write-Output "Namespace template and service activation request accepted: $TEMPLATE_NAME"
