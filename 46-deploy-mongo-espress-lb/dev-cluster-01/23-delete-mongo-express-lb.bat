@echo off
REM --------------+--------------------------------------------------------------------+
REM  Script Name ^| 23-delete-mongo-express-lb.bat                                    ^|
REM  Updated     ^| 2026-11-14                                                        ^|
REM  Version     ^| 1.3                                                               ^|
REM  VCF Version ^| 9.1.1                                                             ^|
REM  Description ^| Delete the MongoDB and Mongo Express namespace and its resources. ^|
REM --------------+--------------------------------------------------------------------+

REM --------------+--------------------------------------------------------------------+
REM  Requirement ^| Details                                                           ^|
REM --------------+--------------------------------------------------------------------+
REM  Runtime     ^| Windows Command Prompt (cmd.exe).                                 ^|
REM  Tools       ^| VCF CLI and kubectl in PATH.                                      ^|
REM  Access      ^| Authenticated VCF context and workload Kubernetes API access.     ^|
REM  Inputs      ^| Set the target cluster and application namespace.                 ^|
REM  Permissions ^| Delete the application namespace and its resources.               ^|
REM  Deletion    ^| Deletes namespace workloads, services, configuration and PVCs.    ^|
REM  Storage     ^| Backing volume removal follows the PV reclaim policy.             ^|
REM --------------+--------------------------------------------------------------------+

REM Keep settings local and preserve literal exclamation marks.
setlocal DisableDelayedExpansion

set "CLUSTER_NAME=dev-cluster-01"
set "NAMESPACE=dev-mongodb-lb"

REM Refresh workload cluster authentication.
vcf context refresh %CLUSTER_NAME% || exit /b 1

REM Select the workload Kubernetes context.
kubectl config use-context "%CLUSTER_NAME%:%CLUSTER_NAME%" || exit /b 1

REM Delete workloads and services in the application namespace.
kubectl delete deployments,services,replicasets,pods --all -n %NAMESPACE% || exit /b 1

REM Delete configuration, credentials, and service accounts in the application namespace.
kubectl delete configmaps,secrets,serviceaccounts --all -n %NAMESPACE% || exit /b 1

REM Delete namespace PVCs; backing volume cleanup follows the PV reclaim policy.
kubectl delete pvc --all -n %NAMESPACE% || exit /b 1

REM Delete the namespace after its resources have been removed.
kubectl delete namespace %NAMESPACE% || exit /b 1

REM Report successful namespace deletion.
echo Namespace %NAMESPACE% deleted.

REM Restore the calling environment.
endlocal
