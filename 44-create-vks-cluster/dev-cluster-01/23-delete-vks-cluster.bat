@echo off
REM -------------+---------------------------------------------------------------+
REM Script Name ^| 23-delete-vks-cluster.bat                                     ^|
REM Updated     ^| 2026-11-15                                                    ^|
REM Version     ^| 1.11                                                          ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                        ^|
REM Description ^| Delete the configured VKS Cluster and wait for removal.       ^|
REM -------------+---------------------------------------------------------------+

REM -------------+---------------------------------------------------------------+
REM Requirement ^| Details                                                       ^|
REM -------------+---------------------------------------------------------------+
REM Runtime     ^| Windows Command Prompt (cmd.exe).                             ^|
REM Tools       ^| VCF CLI, kubectl available in PATH.                           ^|
REM Access      ^| Supervisor API connectivity and required cluster permissions. ^|
REM Context     ^| Existing Supervisor context.                                  ^|
REM -------------+---------------------------------------------------------------+

setlocal DisableDelayedExpansion

set "CONTEXT_NAME=supervisor"
set "REQUEST_TIMEOUT=30"
set "WAIT_TIMEOUT=1800"
set "CLUSTER01_NAMESPACE=dev-namespace"
set "CLUSTER01_NAME=dev-cluster-01"

echo Refreshing Supervisor authentication...
vcf context refresh %CONTEXT_NAME% >nul 2>&1

REM ------------------------------------------------------------------------------------------------------
REM Use either the VCF or the kubectl context command below. Select the Supervisor context.
REM vcf context use %CONTEXT_NAME%
REM vcf cluster delete %CLUSTER01_NAME% -n %CLUSTER01_NAMESPACE% --yes
REM ------------------------------------------------------------------------------------------------------

echo Selecting Supervisor context %CONTEXT_NAME% with kubectl...
kubectl config use-context %CONTEXT_NAME%

echo Submitting the deletion request for Cluster %CLUSTER01_NAME% using kubectl...
kubectl --request-timeout=%REQUEST_TIMEOUT%s -n %CLUSTER01_NAMESPACE% delete cluster %CLUSTER01_NAME% --wait=false

echo Waiting for Cluster %CLUSTER01_NAME% to be removed...
kubectl --request-timeout=%REQUEST_TIMEOUT%s -n %CLUSTER01_NAMESPACE% wait cluster/%CLUSTER01_NAME% --for=delete --timeout=%WAIT_TIMEOUT%s

echo Review the deletion result above for Cluster %CLUSTER01_NAME% in namespace %CLUSTER01_NAMESPACE%.
