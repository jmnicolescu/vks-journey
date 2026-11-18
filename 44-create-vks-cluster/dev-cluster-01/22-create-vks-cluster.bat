@echo off
REM -------------+-----------------------------------------------------------------------------+
REM Script Name ^| 22-create-vks-cluster.bat                                                   ^|
REM Updated     ^| 2026-11-15                                                                  ^|
REM Version     ^| 1.12                                                                        ^|
REM VCF Version ^| 9.1.1.0-545627-2026-09                                                      ^|
REM Description ^| Generate the VKS Cluster manifest, submit it and wait for availability.     ^|
REM -------------+-----------------------------------------------------------------------------+

REM -------------+-----------------------------------------------------------------------------+
REM Requirement ^| Details                                                                     ^|
REM -------------+-----------------------------------------------------------------------------+
REM Runtime     ^| Windows Command Prompt (cmd.exe).                                           ^|
REM Tools       ^| VCF CLI, kubectl available in PATH.                                         ^|
REM Access      ^| Supervisor API connectivity and required cluster permissions.               ^|
REM Context     ^| Existing Supervisor context.                                                ^|
REM Files       ^| Write access to deployment-files beside this script.                        ^|
REM -------------+-----------------------------------------------------------------------------+

setlocal DisableDelayedExpansion

set "CONTEXT_NAME=supervisor"
set "DEPLOYMENT_FILES=%~dp0deployment-files"
set "REQUEST_TIMEOUT=30"
set "WAIT_TIMEOUT=1800"
set "CLUSTER01_NAMESPACE=dev-namespace"
set "CLUSTER01_NAME=dev-cluster-01"
set "CLUSTER01_MANIFEST=create-dev-cluster-01.yaml"

echo Creating deployment files directory %DEPLOYMENT_FILES%...
if not exist "%DEPLOYMENT_FILES%" mkdir "%DEPLOYMENT_FILES%"

echo Creating the cluster manifest with the configured topology and sizing...
> "%DEPLOYMENT_FILES%\%CLUSTER01_MANIFEST%" (
    echo apiVersion: cluster.x-k8s.io/v1beta2
    echo kind: Cluster
    echo metadata:
    echo   name: %CLUSTER01_NAME%
    echo   namespace: %CLUSTER01_NAMESPACE%
    echo spec:
    echo   clusterNetwork:
    echo     pods:
    echo       cidrBlocks:
    echo         - 10.95.0.0/16
    echo     services:
    echo       cidrBlocks:
    echo         - 10.96.0.0/12
    echo     serviceDomain: cluster.local
    echo   topology:
    echo     classRef:
    echo       name: builtin-generic-v3.7.0
    echo       namespace: vmware-system-vks-public
    echo     version: v1.35.6---vmware.2-vkr.3
    echo     variables:
    echo       - name: vmClass
    echo         value: best-effort-medium
    echo       - name: storageClass
    echo         value: vsan-default-storage-policy
    echo       - name: bootstrapAddons
    echo         value:
    echo           cniRef:
    echo             name: antrea
    echo             namespace: vmware-system-vks-public
    echo       - name: kubernetes
    echo         value:
    echo           certificateRotation:
    echo             enabled: true
    echo             renewalDaysBeforeExpiry: 90
    echo           security:
    echo             podSecurityStandard:
    echo               audit: restricted
    echo               auditVersion: latest
    echo               enforce: privileged
    echo               enforceVersion: latest
    echo               warn: privileged
    echo               warnVersion: latest
    echo     controlPlane:
    echo       replicas: 3
    echo       metadata:
    echo         annotations:
    echo           run.tanzu.vmware.com/resolve-os-image: os-name=photon
    echo     workers:
    echo       machineDeployments:
    echo         - class: node-pool
    echo           name: %CLUSTER01_NAME%-np01
    echo           replicas: 3
    echo           metadata:
    echo             annotations:
    echo               run.tanzu.vmware.com/resolve-os-image: os-name=photon
    echo           variables:
    echo             overrides:
    echo               - name: volumes
    echo                 value:
    echo                   - name: vol-containerd
    echo                     mountPath: /var/lib/containerd
    echo                     storageClass: vsan-default-storage-policy
    echo                     capacity: 30Gi
)

echo Refreshing Supervisor authentication...
vcf context refresh %CONTEXT_NAME% >nul 2>&1

REM ------------------------------------------------------------------------------------------------------
REM Use either the VCF or the kubectl context command below. Select the Supervisor context.
REM vcf context use %CONTEXT_NAME%
REM vcf cluster create -f "%DEPLOYMENT_FILES%\%CLUSTER01_MANIFEST%" --yes
REM ------------------------------------------------------------------------------------------------------

echo Selecting Supervisor context %CONTEXT_NAME% with kubectl...
kubectl config use-context %CONTEXT_NAME%

echo Applying the manifest to create or update Cluster %CLUSTER01_NAME%...
kubectl apply -f "%DEPLOYMENT_FILES%\%CLUSTER01_MANIFEST%"

echo Waiting for Cluster %CLUSTER01_NAME% to report availability...
kubectl --request-timeout=%REQUEST_TIMEOUT%s -n %CLUSTER01_NAMESPACE% wait cluster/%CLUSTER01_NAME% --for=condition=Available=True --timeout=%WAIT_TIMEOUT%s

REM Alternative: list the clusters visible to VCF.
REM vcf cluster list -A

echo Listing Cluster API clusters across all Supervisor namespaces...
kubectl get clusters -A

REM echo Displaying the current state of Cluster %CLUSTER01_NAME%...
REM kubectl -n %CLUSTER01_NAMESPACE% get clusters %CLUSTER01_NAME% -o yaml

echo Review the availability result above for Cluster %CLUSTER01_NAME% in namespace %CLUSTER01_NAMESPACE%.
