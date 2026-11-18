#Requires -Version 7.0
#-------------+------------------------------------------------------------------------------------------------+
# Script Name | 12-remove-vsphere-namespace.ps1                                                                |
# Updated     | 2026-11-15                                                                                     |
# Version     | 1.6                                                                                            |
# VCF Version | 9.1.1.0-545627-2026-09                                                                         |
# Description | Submit deletion of one namespace and its workloads.                                            |
#-------------+------------------------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------------------------+
# Requirement | Details                                                                                        |
#-------------+------------------------------------------------------------------------------------------------+
# Runtime     | PowerShell 7.4+ for REST timeout parameters.                                                   |
# Tools       | Native PowerShell HTTP and JSON commands.                                                      |
# Inputs      | Review the editable connection, target and resource settings in this script.                   |
# Access      | HTTPS to vCenter; valid credentials and namespace management permissions.                      |
# Effect      | Deletes the selected namespace and its workloads without a confirmation prompt.                |
#-------------+------------------------------------------------------------------------------------------------+

# Stop when a command fails.
$ErrorActionPreference = 'Stop'

$VCENTER = 'mgmt-vcsa.platformlab.vcf'
$VC_USER = 'labadministrator@vsphere.local'
$VC_PASS = 'VMwar3!!VMwar3!!'

$CONNECT_TIMEOUT = 10
$REQUEST_TIMEOUT = 120

$NAMESPACE_NAME = 'dev-namespace'

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

# Submit deletion of the namespace and its workloads.
Invoke-RestMethod -Method Delete -Uri "https://$VCENTER/api/vcenter/namespaces/instances/$NAMESPACE_NAME" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Close the vCenter API session.
Invoke-RestMethod -Method Delete -Uri "https://$VCENTER/api/session" `
    -Headers $HEADERS -SkipCertificateCheck `
    -ConnectionTimeoutSeconds $CONNECT_TIMEOUT -OperationTimeoutSeconds $REQUEST_TIMEOUT

# Report request acceptance without claiming namespace removal is complete.
Write-Output "Namespace deletion request accepted: $NAMESPACE_NAME; removal has not been checked."
