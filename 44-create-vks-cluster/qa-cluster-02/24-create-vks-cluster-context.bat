@echo off
REM -------------+--------------------------------------------------------------------+
REM Script Name ^| 24-create-vks-cluster-context.bat                                  ^|
REM Updated     ^| 2026-11-15                                                         ^|
REM Version     ^| 1.12                                                               ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                             ^|
REM Description ^| Create or recreate and activate the local VCF CLI cluster context. ^|
REM -------------+--------------------------------------------------------------------+

REM -------------+--------------------------------------------------------------------+
REM Requirement ^| Details                                                            ^|
REM -------------+--------------------------------------------------------------------+
REM Runtime     ^| Windows Command Prompt (cmd.exe).                                  ^|
REM Tools       ^| VCF CLI, kubectl available in PATH.                                ^|
REM Access      ^| Supervisor API connectivity and required cluster permissions.      ^|
REM TLS         ^| Supervisor TLS verification is skipped by the context command.     ^|
REM -------------+--------------------------------------------------------------------+

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

set "CLUSTER_NAMESPACE=qa-namespace"
set "CLUSTER_NAME=qa-cluster-02"

echo Checking that vcf, kubectl and openssl are available...
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

REM --insecure-skip-tls-verify disables verification of the Supervisor TLS certificate.
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
