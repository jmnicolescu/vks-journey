#Requires -Version 7.0
#---------------+----------------------------------------------------------------------------+
# Script Name   | 02-get-supervisor-endpoint-ps7.ps1                                         |
# Updated       | 2026-11-15                                                                 |
# Version       | 1.8                                                                        |
# VCF Version   | 9.1.1.0-545627-2026-09                                                     |
# Description   | Retrieve the Supervisor API endpoint and save Windows environment          |
#               | settings.                                                                  |
#---------------+----------------------------------------------------------------------------+

#---------------+----------------------------------------------------------------------------+
# Requirement   | Details                                                                    |
#---------------+----------------------------------------------------------------------------+
# Runtime       | PowerShell 7 or newer on Windows.                                          |
# Tools         | Native Invoke-RestMethod and .NET environment commands.                    |
# Access        | vCenter HTTPS access, valid credentials and Supervisor read permissions.   |
# Configuration | Set VCENTER, VC_USER, VC_PASS and CLUSTER_NAME in this script.             |
# Execution     | PowerShell execution policy must permit this script.                       |
# Environment   | Writes SUPERVISOR_API_ENDPOINT for the user and current PowerShell         |
#               | process.                                                                   |
# TLS           | Invoke-RestMethod -SkipCertificateCheck bypasses certificate validation.   |
#---------------+----------------------------------------------------------------------------+

# ------------------------------------------------------------------------------------------------------
# If execution is blocked because this script is unsigned, run these commands
# in your PowerShell terminal before launching the script:
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#
# Permanently allow unsigned scripts, including scripts on mapped network drives,
# for the current user. Group Policy settings still take precedence.
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
# ------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------
# Install PowerShell 7 alongside Windows PowerShell 5.1.
# After installation, run 'pwsh' in a new terminal to start PowerShell 7.
# winget install --id Microsoft.PowerShell --source winget
# ------------------------------------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$VCENTER = 'mgmt-vcsa.platformlab.vcf'
$VC_USER = 'labadministrator@vsphere.local'
$VC_PASS = 'VMwar3!!VMwar3!!'
$CLUSTER_NAME = 'platformlab-cl01'

# Log in to vCenter.
$baseUrl = 'https://' + $VCENTER + '/api'
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($VC_USER + ':' + $VC_PASS))
$sessionId = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$baseUrl/session" -Headers @{Authorization = "Basic $basicAuth"}
$headers = @{'vmware-api-session-id' = $sessionId}

# Find the cluster and retrieve the Supervisor endpoint.
$clusterName = [Uri]::EscapeDataString($CLUSTER_NAME)
$clusters = Invoke-RestMethod -SkipCertificateCheck -Method Get -Headers $headers -Uri "$baseUrl/vcenter/cluster?names=$clusterName"
$clusterId = @($clusters)[0].cluster
$summaries = Invoke-RestMethod -SkipCertificateCheck -Method Get -Headers $headers -Uri "$baseUrl/vcenter/namespace-management/supervisors/summaries"
$cluster = Invoke-RestMethod -SkipCertificateCheck -Method Get -Headers $headers -Uri "$baseUrl/vcenter/namespace-management/clusters/$clusterId"

Write-Output ('Supervisor:   ' + $summaries.items[0].info.name)
Write-Output ('Cluster:      ' + $CLUSTER_NAME)
Write-Output ('API endpoint: ' + $cluster.api_server_cluster_endpoint)

# Read the discovered Supervisor endpoint.
$SUPERVISOR_ENDPOINT = $cluster.api_server_cluster_endpoint

# Stop before changing the environment if no endpoint was returned.
if ([string]::IsNullOrWhiteSpace($SUPERVISOR_ENDPOINT)) {
    throw 'No Supervisor API endpoint was returned.'
}

# Persist the endpoint for the current Windows user across sign-ins.
[Environment]::SetEnvironmentVariable('SUPERVISOR_API_ENDPOINT', $SUPERVISOR_ENDPOINT, 'User')

# Update the endpoint in this PowerShell session.
$env:SUPERVISOR_API_ENDPOINT = $SUPERVISOR_ENDPOINT

# Confirm the saved environment variable.
Write-Output ('Saved user environment variable: SUPERVISOR_API_ENDPOINT=' + $SUPERVISOR_ENDPOINT)

# Log out of vCenter.
Invoke-RestMethod -SkipCertificateCheck -Method Delete -Headers $headers -Uri "$baseUrl/session" | Out-Null
