@echo off
REM -------------+-----------------------------------------------------------------------+
REM Script Name ^| 21-create-supervisor-context.bat                                      ^|
REM Updated     ^| 2026-11-15                                                            ^|
REM Version     ^| 1.13                                                                  ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                                ^|
REM Description ^| Create or recreate and activate the local VCF CLI Supervisor context. ^|
REM -------------+-----------------------------------------------------------------------+

REM -------------+-----------------------------------------------------------------------+
REM Requirement ^| Details                                                               ^|
REM -------------+-----------------------------------------------------------------------+
REM Runtime     ^| Windows Command Prompt (cmd.exe).                                     ^|
REM Tools       ^| VCF CLI, kubectl available in PATH.                                   ^|
REM Access      ^| Supervisor API connectivity and required cluster permissions.         ^|
REM TLS         ^| Supervisor TLS verification is skipped by the context command.        ^|
REM-------------+-----------------------------------------------------------------------+

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
set "CONTEXT_NAME=supervisor"

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
vcf context delete %CONTEXT_NAME% -y

echo Creating Supervisor context %CONTEXT_NAME% ...
vcf context create %CONTEXT_NAME% --endpoint %SUPERVISOR_API_ENDPOINT% --username %VCF_CLI_VSPHERE_USERNAME% --insecure-skip-tls-verify --type k8s --auth-type basic

REM ------------------------------------------------------------------------------------------------------
REM Use either the VCF or the kubectl context command below.
REM vcf context use %CONTEXT_NAME%
REM vcf context list
REM ------------------------------------------------------------------------------------------------------

echo Activating %CONTEXT_NAME% context: %CONTEXT_NAME%
kubectl config use-context %CONTEXT_NAME%

echo Display available contexts.
kubectl config get-contexts

echo Verifying Kubernetes cluster connectivity...
kubectl get nodes

echo Review the context activation and connectivity results above for %CONTEXT_NAME%.
