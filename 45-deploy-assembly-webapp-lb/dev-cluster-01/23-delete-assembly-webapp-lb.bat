@echo off
REM -----------------+----------------------------------------------------------------+
REM  Script Name    ^| 23-delete-assembly-webapp-lb.bat                              ^|
REM  Updated        ^| 2026-11-14                                                    ^|
REM  Version        ^| 1.3                                                           ^|
REM  VCF Version    ^| 9.1.1                                                         ^|
REM  Description    ^| Delete the Assembly WebApp namespace and all resources in it. ^|
REM -----------------+----------------------------------------------------------------+

REM -----------------+----------------------------------------------------------------+
REM  Requirement    ^| Details                                                       ^|
REM -----------------+----------------------------------------------------------------+
REM  Runtime        ^| Windows Command Prompt (cmd.exe).                             ^|
REM  Tools          ^| VCF CLI and kubectl available in PATH.                        ^|
REM  Authentication ^| Existing VCF context with credentials that can be refreshed.  ^|
REM  Access         ^| Workload cluster API connectivity.                            ^|
REM  Permissions    ^| Manage the application namespace and its resources.           ^|
REM  Configuration  ^| Set the target cluster name and application namespace.        ^|
REM  Effect         ^| Deletes the application namespace and all resources in it.    ^|
REM -----------------+----------------------------------------------------------------+

REM Keep script variables local and preserve literal exclamation marks.
setlocal DisableDelayedExpansion

set "CLUSTER_NAME=dev-cluster-01"
set "NAMESPACE=dev-assembly-lb"

REM Refresh workload cluster authentication.
vcf context refresh %CLUSTER_NAME% || exit /b 1

REM Select the workload Kubernetes context.
kubectl config use-context "%CLUSTER_NAME%:%CLUSTER_NAME%" || exit /b 1

REM Delete the application workloads and services in the namespace.
kubectl delete --all deployments,services,replicasets,pods --namespace=%NAMESPACE% || exit /b 1

REM Delete service accounts and secrets in the namespace.
kubectl delete --all serviceaccounts,secrets --namespace=%NAMESPACE% || exit /b 1

REM Delete the namespace and all remaining resources in it.
kubectl delete namespace %NAMESPACE% || exit /b 1

REM Report that the namespace was deleted.
echo Namespace %NAMESPACE% deleted.
