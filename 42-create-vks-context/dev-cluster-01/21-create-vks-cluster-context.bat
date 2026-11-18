@echo off
REM ---------------+--------------------------------------------------------------------+
REM  Script Name   ^| 21-create-vks-cluster-context.bat                                  ^|
REM  Updated       ^| 2026-11-15                                                         ^|
REM  Version       ^| 1.12                                                               ^|
REM  VCF Version   ^| 9.1.1.0-545627-2026-09                                             ^|
REM  Description   ^| Recreate and activate the local VKS context; list nodes.           ^|
REM ---------------+--------------------------------------------------------------------+

REM ---------------+--------------------------------------------------------------------+
REM  Requirement   ^| Details                                                            ^|
REM ---------------+--------------------------------------------------------------------+
REM  Runtime       ^| Windows Command Prompt (cmd.exe).                                  ^|
REM  Tools         ^| VCF CLI, kubectl in PATH.                                          ^|
REM  Access        ^| Reachable Supervisor and target Kubernetes API; SSO credentials.   ^|
REM  Permissions   ^| Target context access and permission to list Kubernetes nodes.     ^|
REM  Configuration ^| Set endpoint, credentials and context or workload cluster inputs.  ^|
REM  TLS           ^| Supervisor certificate verification is disabled by this script.    ^|
REM  Files         ^| Write access to local VCF CLI configuration and kubeconfig.        ^|
REM  Effects       ^| Replace the named local context and change the active kubecontext. ^|
REM ---------------+--------------------------------------------------------------------+

setlocal DisableDelayedExpansion

REM ------------------------------------------------------------------------------------------------------
REM SECURITY WARNING:
REM The VCF_CLI_VSPHERE_PASSWORD variable contains a plaintext vCenter SSO password.
REM Hardcoding credentials is NOT recommended for production environments.
REM Never commit scripts containing passwords to Git repositories or share them publicly.
REM Prefer secure credential management or interactive authentication.
REM If exposed, rotate the password immediately.
REM ------------------------------------------------------------------------------------------------------

set "VCF_CLI_VSPHERE_USERNAME=labadministrator@vsphere.local"
set "VCF_CLI_VSPHERE_PASSWORD=VMwar3!!VMwar3!!"
set "SUPERVISOR_API_ENDPOINT=10.55.16.4"

set "CLUSTER_NAMESPACE=dev-namespace"
set "CLUSTER_NAME=dev-cluster-01"

echo Checking that vcf, kubectl are available...
for %%T in (vcf kubectl) do (
    where %%T >nul 2>&1
    if errorlevel 1 (
        echo ERROR: %%T is not installed or is not available in the system PATH. >&2
        echo Please install %%T and ensure it is accessible before proceeding. >&2
        exit /b 1
    )
)

echo Deleting the old context if it exists...
vcf context delete %CLUSTER_NAME% -y

REM Create the workload context without verifying the Supervisor TLS certificate.
vcf context create %CLUSTER_NAME% --endpoint %SUPERVISOR_API_ENDPOINT% --username %VCF_CLI_VSPHERE_USERNAME% --workload-cluster-namespace %CLUSTER_NAMESPACE% --workload-cluster-name %CLUSTER_NAME% --insecure-skip-tls-verify --type k8s --auth-type basic

REM ------------------------------------------------------------------------------------------------------
REM Use either the VCF or the kubectl context command below.
REM vcf context use %CLUSTER_NAME%:%CLUSTER_NAME%
REM vcf context list
REM ------------------------------------------------------------------------------------------------------

echo Activating VKS context: %CLUSTER_NAME%:%CLUSTER_NAME%
kubectl config use-context %CLUSTER_NAME%:%CLUSTER_NAME%

echo Display available contexts.
kubectl config get-contexts

echo Verifying Kubernetes cluster connectivity...
kubectl get nodes

echo Review the context activation and connectivity results above for %CLUSTER_NAME%:%CLUSTER_NAME%.
