@echo off
REM -----------------+--------------------------------------------------------------------+
REM  Script Name    ^| 22-deploy-assembly-webapp-lb.bat                                  ^|
REM  Updated        ^| 2026-11-18                                                        ^|
REM  Version        ^| 1.4                                                               ^|
REM  VCF Version    ^| 9.1.1                                                             ^|
REM  Description    ^| Deploy the Assembly WebApp with a LoadBalancer service.           ^|
REM -----------------+--------------------------------------------------------------------+

REM -----------------+--------------------------------------------------------------------+
REM  Requirement    ^| Details                                                           ^|
REM -----------------+--------------------------------------------------------------------+
REM  Runtime        ^| Windows Command Prompt (cmd.exe).                                 ^|
REM  Tools          ^| VCF CLI and kubectl available in PATH.                            ^|
REM  Authentication ^| Existing VCF context with credentials that can be refreshed.      ^|
REM  Access         ^| Workload cluster API connectivity.                                ^|
REM  Permissions    ^| Manage the application namespace and its resources.               ^|
REM  Configuration  ^| Set the target cluster name and application namespace.            ^|
REM  Infrastructure ^| VKS cluster with LoadBalancer support and container image access. ^|
REM  Files          ^| Write access to deployment-files in the current directory.        ^|
REM -----------------+--------------------------------------------------------------------+

REM Keep script variables local and preserve literal exclamation marks.
setlocal DisableDelayedExpansion

set "CLUSTER_NAME=qa-cluster-02"
set "NAMESPACE=qa-assembly-lb"

set "DEPLOYMENT_FILES=deployment-files"
set "ROLLOUT_TIMEOUT=300s"
set "LOAD_BALANCER_TIMEOUT=300s"

REM Refresh workload cluster authentication.
vcf context refresh %CLUSTER_NAME% || exit /b 1

REM Select the workload Kubernetes context.
kubectl config use-context "%CLUSTER_NAME%:%CLUSTER_NAME%" || exit /b 1

REM Create the deployment files directory.
if not exist "%DEPLOYMENT_FILES%\" mkdir "%DEPLOYMENT_FILES%"

REM Create the application namespace with privileged Pod Security, auditing and warnings enforcement.
(
echo apiVersion: v1
echo kind: Namespace
echo metadata:
echo     name: %NAMESPACE%
echo     labels:
echo       pod-security.kubernetes.io/enforce: privileged
echo       pod-security.kubernetes.io/audit: privileged
echo       pod-security.kubernetes.io/warn: privileged
) > "%DEPLOYMENT_FILES%\10-%NAMESPACE%-namespace.yaml"

REM Apply the namespace manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\10-%NAMESPACE%-namespace.yaml" || exit /b 1

REM Write the deployment and LoadBalancer service manifest.
(
echo apiVersion: apps/v1
echo kind: Deployment
echo metadata:
echo   name: assembly-deployment
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: assembly-webapp
echo spec:
echo   replicas: 3
echo   selector:
echo     matchLabels:
echo       app: assembly-webapp
echo   template:
echo     metadata:
echo       name: assembly-webapp-pod
echo       labels:
echo         app: assembly-webapp
echo     spec:
echo       containers:
echo       - name: assembly-webapp
echo         image: jmnicolescu/assembly-webapp:latest
echo         imagePullPolicy: Always
echo         ports:
echo         - containerPort: 8080
echo ---
echo apiVersion: v1
echo kind: Service
echo metadata:
echo   name: assembly-service
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: assembly-webapp
echo spec:
echo   type: LoadBalancer
echo   selector:
echo     app: assembly-webapp
echo   ports:
echo     - protocol: TCP
echo       port: 8080
echo       targetPort: 8080
) > "%DEPLOYMENT_FILES%\11-%NAMESPACE%-deployment.yaml"

REM Apply the deployment and LoadBalancer service manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\11-%NAMESPACE%-deployment.yaml" || exit /b 1

REM Wait for the deployment rollout to complete.
kubectl rollout status deployment/assembly-deployment -n %NAMESPACE% --timeout=%ROLLOUT_TIMEOUT% || exit /b 1

REM Report that the deployment rollout completed.
echo Assembly WebApp deployment ready in namespace %NAMESPACE%.

REM Wait for the LoadBalancer service to receive an IP address.
kubectl wait service/assembly-service -n %NAMESPACE% --for="jsonpath={.status.loadBalancer.ingress[0].ip}" --timeout=%LOAD_BALANCER_TIMEOUT% || exit /b 1

REM ------------------------------------------------------------------------------------------------------------
echo Display Assembly WebApp resources, LoadBalancer configuration, and HTTP access.
REM ------------------------------------------------------------------------------------------------------------

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Assembly WebApp resources
echo # ------------------------------------------------------------------------------------------------------------
kubectl get all -n %NAMESPACE% || exit /b 1

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Assembly WebApp pods and container images
echo # ------------------------------------------------------------------------------------------------------------
kubectl get pods -n %NAMESPACE% -o "custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image" || exit /b 1

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Assembly WebApp LoadBalancer service
echo # ------------------------------------------------------------------------------------------------------------
kubectl get service assembly-service -n %NAMESPACE% -o wide

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Assembly WebApp service endpoints
echo # ------------------------------------------------------------------------------------------------------------
kubectl get endpointslices -n %NAMESPACE% -l kubernetes.io/service-name=assembly-service

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # LoadBalancer IP address and service port
echo # ------------------------------------------------------------------------------------------------------------

echo Read the assigned LoadBalancer IP address.
kubectl get service assembly-service -n %NAMESPACE% -o "jsonpath={.status.loadBalancer.ingress[0].ip}" > "%DEPLOYMENT_FILES%\assembly-lb-ip.txt" || exit /b 1

echo Read the captured IP address into a local variable.
set /p LB_IP=<"%DEPLOYMENT_FILES%\assembly-lb-ip.txt"

echo Remove the temporary IP address file.
del "%DEPLOYMENT_FILES%\assembly-lb-ip.txt"

echo Read the exposed HTTP service port.
kubectl get service assembly-service -n %NAMESPACE% -o "jsonpath={.spec.ports[0].port}" > "%DEPLOYMENT_FILES%\assembly-lb-port.txt"

echo Read the captured service port into a local variable.
set /p LB_PORT=<"%DEPLOYMENT_FILES%\assembly-lb-port.txt"

echo Remove the temporary service port file.
del "%DEPLOYMENT_FILES%\assembly-lb-port.txt"

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo LoadBalancer IP Address : %LB_IP%
echo Service Port            : %LB_PORT%
echo # ------------------------------------------------------------------------------------------------------------

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Test HTTP connectivity directly through the LoadBalancer IP
echo # ------------------------------------------------------------------------------------------------------------
echo curl -fv --max-time 15 http://%LB_IP%:%LB_PORT%/

echo.
echo # ------------------------------------------------------------------------------------------------------------
echo # Assembly WebApp HTTP endpoint
echo # ------------------------------------------------------------------------------------------------------------
echo Assembly WebApp URL: http://%LB_IP%:%LB_PORT%/
