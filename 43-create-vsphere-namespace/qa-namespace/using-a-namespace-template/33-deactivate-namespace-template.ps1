#Requires -Version 7.4
#-------------+------------------------------------------------------------------------------------------+
# Script Name | 33-deactivate-namespace-template.ps1                                                     |
# Updated     | 2026-11-15                                                                               |
# Version     | 1.6                                                                                      |
# VCF Version | 9.1.1.0-545627-2026-09                                                                   |
# Description | Deactivate Namespace Service to stop use of the self-service namespace template.         |
#-------------+------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                  |
#-------------+------------------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.4+ for REST timeout parameters.                                             |
# Tools       | Native PowerShell HTTP and JSON commands.                                                |
# Inputs      | Review the connection and target settings in this script.                                |
# Access      | HTTPS to vCenter; valid credentials and inventory read access.                           |
# Permissions | Namespaces.SelfServiceManage on the selected cluster.                                    |
# Resources   | Existing Supervisor with active Namespace Service.                                       |
# Effect      | Stops new self-service creation; retains existing namespaces and template configuration. |
#-------------+------------------------------------------------------------------------------------------+

# Stop when a command fails.
$ErrorActionPreference = 'Stop'

$VCENTER = 'mgmt-vcsa.platformlab.vcf'
$VC_USER = 'labadministrator@vsphere.local'
$VC_PASS = 'VMwar3!!VMwar3!!'

$CONNECT_TIMEOUT = 10
$REQUEST_TIMEOUT = 120

$DATACENTER_NAME = 'platformlab-dc01'
$CLUSTER_NAME = 'platformlab-cl01'

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

# Deactivate Namespace Service; the template configuration and existing namespaces are retained.
Invoke-RestMethod -Method Post -Uri "https://$VCENTER/api/vcenter/namespaces/namespace-self-service/$($CLUSTER_ID)?action=deactivate" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Close the vCenter API session.
Invoke-RestMethod -Method Delete -Uri "https://$VCENTER/api/session" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Report acceptance of the Namespace Service deactivation request.
Write-Output "Namespace Service deactivation request accepted: $CLUSTER_NAME"
