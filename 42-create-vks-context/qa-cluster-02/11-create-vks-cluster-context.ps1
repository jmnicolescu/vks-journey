#Requires -Version 7.0
#---------------+--------------------------------------------------------------------+
# Script Name   | 11-create-vks-cluster-context.ps1                                  |
# Updated       | 2026-11-15                                                         |
# Version       | 1.16                                                               |
# VCF Version   | 9.1.1.0-545627-2026-09                                             |
# Description   | Recreate and activate the local VKS context; list nodes.           |
#---------------+--------------------------------------------------------------------+

#---------------+--------------------------------------------------------------------+
# Requirement   | Details                                                            |
#---------------+--------------------------------------------------------------------+
# Runtime       | PowerShell 7.0 or later.                                           |
# Tools         | VCF CLI, kubectl in PATH.                                          |
# Access        | Reachable Supervisor and target Kubernetes API; SSO credentials.   |
# Permissions   | Target context access and permission to list Kubernetes nodes.     |
# Configuration | Set endpoint, credentials and context or workload cluster inputs.  |
# TLS           | Uses retrieved certificate; verify its fingerprint independently.  |
# Files         | Write access to the temporary certificate file and local configs.  |
# Effects       | Replace the named local context and change the active kubecontext. |
#---------------+--------------------------------------------------------------------+

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------------------------------
# SECURITY WARNING:
# The VCF_CLI_VSPHERE_PASSWORD variable contains a plaintext vCenter SSO password.
# Hardcoding credentials is NOT recommended for production environments.
# Never commit scripts containing passwords to Git repositories or share them publicly.
# Prefer secure credential management or interactive authentication.
# If exposed, rotate the password immediately.
# ------------------------------------------------------------------------------------------------------

$env:VCF_CLI_VSPHERE_USERNAME = 'labadministrator@vsphere.local'
$env:VCF_CLI_VSPHERE_PASSWORD = 'VMwar3!!VMwar3!!'
$SUPERVISOR_API_ENDPOINT = '10.55.16.4'
$CERTIFICATE_FILE = Join-Path ([IO.Path]::GetTempPath()) 'SUPERVISOR.crt'

$CLUSTER_NAMESPACE = 'qa-namespace'
$CLUSTER_NAME = 'qa-cluster-02'

Write-Host "Checking that vcf and kubectl are available..."
Get-Command vcf, kubectl -ErrorAction Stop | Out-Null

Write-Host "Removing the previous Supervisor certificate file..."
Remove-Item -LiteralPath $CERTIFICATE_FILE -Force -ErrorAction SilentlyContinue

Write-Host "Retrieving the Supervisor API certificate..."
$tcp = [Net.Sockets.TcpClient]::new($SUPERVISOR_API_ENDPOINT, 443)
$tls = [Net.Security.SslStream]::new($tcp.GetStream(), $false, { $true })
$tls.AuthenticateAsClient($SUPERVISOR_API_ENDPOINT)
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($tls.RemoteCertificate)
$base64 = [Convert]::ToBase64String($certificate.RawData, [Base64FormattingOptions]::InsertLineBreaks)
Set-Content -LiteralPath $CERTIFICATE_FILE -Value "-----BEGIN CERTIFICATE-----`n$base64`n-----END CERTIFICATE-----" -Encoding ascii
$tls.Dispose()
$tcp.Dispose()
$certificate.Dispose()

Write-Host "Deleting the old context if it exists..."
vcf context delete $CLUSTER_NAME -y

# Not used because --insecure-skip-tls-verify disables verification of the Supervisor TLS certificate.
# vcf context create $CLUSTER_NAME --endpoint $SUPERVISOR_API_ENDPOINT --username $env:VCF_CLI_VSPHERE_USERNAME --workload-cluster-namespace $CLUSTER_NAMESPACE --workload-cluster-name $CLUSTER_NAME --insecure-skip-tls-verify --type k8s --auth-type basic

Write-Host "Creating VKS workload context $CLUSTER_NAME using the saved Supervisor TLS certificate..."
vcf context create $CLUSTER_NAME --endpoint $SUPERVISOR_API_ENDPOINT --username $env:VCF_CLI_VSPHERE_USERNAME --workload-cluster-namespace $CLUSTER_NAMESPACE --workload-cluster-name $CLUSTER_NAME --ca-certificate "$CERTIFICATE_FILE" --type k8s --auth-type basic


# ------------------------------------------------------------------------------------------------------
# Use either the VCF or the kubectl context command below.
# vcf context use "$($CLUSTER_NAME):$CLUSTER_NAME"
# vcf context list
# ------------------------------------------------------------------------------------------------------

Write-Host "Activating VKS context: $($CLUSTER_NAME):$CLUSTER_NAME"
kubectl config use-context "$($CLUSTER_NAME):$CLUSTER_NAME"

Write-Host "Display available contexts."
kubectl config get-contexts

Write-Host "Verifying Kubernetes cluster connectivity..."
kubectl get nodes

Write-Host "Review the context activation and connectivity results above for $($CLUSTER_NAME):$CLUSTER_NAME."
