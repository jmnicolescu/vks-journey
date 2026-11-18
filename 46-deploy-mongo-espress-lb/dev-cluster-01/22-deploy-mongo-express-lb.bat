@echo off
REM --------------+----------------------------------------------------------------+
REM  Script Name ^| 22-deploy-mongo-express-lb.bat                                ^|
REM  Updated     ^| 2026-11-18                                                    ^|
REM  Version     ^| 1.7                                                           ^|
REM  VCF Version ^| 9.1.1.0-545627-2026-09                                        ^|
REM  Description ^| Deploy MongoDB and Mongo Express; report LoadBalancer access. ^|
REM --------------+----------------------------------------------------------------+

REM --------------+----------------------------------------------------------------+
REM  Requirement ^| Details                                                       ^|
REM --------------+----------------------------------------------------------------+
REM  Runtime     ^| Windows Command Prompt (cmd.exe).                             ^|
REM  Tools       ^| VCF CLI and kubectl in PATH.                                  ^|
REM  Access      ^| Authenticated VCF context and workload Kubernetes API access. ^|
REM  Inputs      ^| Set the target cluster and application namespace.             ^|
REM  Permissions ^| Create and update namespaces and application resources.       ^|
REM  Storage     ^| Configured storage class and dynamic volume provisioning.     ^|
REM  Network     ^| Cluster image pulls and LoadBalancer provisioning.            ^|
REM  Files       ^| Write access to deployment-files beside this script.          ^|
REM  Images      ^| MongoDB 9.0.8; Mongo Express 1.0.2 (Node 20, Alpine 3.19).    ^|
REM --------------+----------------------------------------------------------------+

REM Keep settings local and preserve literal exclamation marks.
setlocal DisableDelayedExpansion

set "CLUSTER_NAME=dev-cluster-01"
set "NAMESPACE=dev-mongodb-lb"

set "STORAGE_CLASS=vsan-default-storage-policy"
set "ROLLOUT_TIMEOUT=300s"
set "LOAD_BALANCER_TIMEOUT=300s"

REM Resolve the deployment files directory beside this script.
set "DEPLOYMENT_FILES=%~dp0deployment-files"

REM Refresh workload cluster authentication.
vcf context refresh %CLUSTER_NAME% || exit /b 1

REM Select the workload Kubernetes context.
kubectl config use-context "%CLUSTER_NAME%:%CLUSTER_NAME%" || exit /b 1

REM Create the deployment files directory.
if not exist "%DEPLOYMENT_FILES%" mkdir "%DEPLOYMENT_FILES%"

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

REM Write the Secret manifest.
(
echo apiVersion: v1
echo kind: Secret
echo metadata:
echo     name: mongodb-secret
echo     namespace: %NAMESPACE%
echo type: Opaque
echo data:
echo     mongo-root-username: YWRtaW4=
echo     mongo-root-password: c3VwZXJzZWNyZXQ=
echo     mongo-express-password: cGFzcw==
) > "%DEPLOYMENT_FILES%\11-%NAMESPACE%-secret.yaml"

REM Write the PersistentVolumeClaim manifest.
(
echo apiVersion: v1
echo kind: PersistentVolumeClaim
echo metadata:
echo   name: mongodb-pvc
echo   namespace: %NAMESPACE%
echo spec:
echo   accessModes:
echo   - ReadWriteOnce
echo   resources:
echo     requests:
echo       storage: 5Gi
echo   storageClassName: %STORAGE_CLASS%
) > "%DEPLOYMENT_FILES%\12-%NAMESPACE%-pvc.yaml"

REM Write the MongoDB Deployment, Service, and ConfigMap manifests.
(
echo apiVersion: apps/v1
echo kind: Deployment
echo metadata:
echo   name: mongodb-deployment
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: mongodb
echo spec:
echo   replicas: 1
echo   strategy:
echo     type: Recreate
echo   selector:
echo     matchLabels:
echo       app: mongodb
echo   template:
echo     metadata:
echo       labels:
echo         app: mongodb
echo     spec:
echo       containers:
echo         - name: mongodb
echo           image: mongo:9.0.8
echo           imagePullPolicy: IfNotPresent
echo           ports:
echo             - name: mongodb
echo               containerPort: 27017
echo               protocol: TCP
echo           env:
echo             - name: MONGO_INITDB_ROOT_USERNAME
echo               valueFrom:
echo                 secretKeyRef:
echo                   name: mongodb-secret
echo                   key: mongo-root-username
echo             - name: MONGO_INITDB_ROOT_PASSWORD
echo               valueFrom:
echo                 secretKeyRef:
echo                   name: mongodb-secret
echo                   key: mongo-root-password
echo           volumeMounts:
echo             - name: mongodb-storage
echo               mountPath: /data/db
echo           startupProbe:
echo             tcpSocket:
echo               port: mongodb
echo             periodSeconds: 10
echo             failureThreshold: 30
echo           readinessProbe:
echo             tcpSocket:
echo               port: mongodb
echo             initialDelaySeconds: 5
echo             periodSeconds: 10
echo           livenessProbe:
echo             tcpSocket:
echo               port: mongodb
echo             initialDelaySeconds: 30
echo             periodSeconds: 20
echo       volumes:
echo         - name: mongodb-storage
echo           persistentVolumeClaim:
echo             claimName: mongodb-pvc
echo ---
echo apiVersion: v1
echo kind: Service
echo metadata:
echo   name: mongodb-service
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: mongodb
echo spec:
echo   type: ClusterIP
echo   selector:
echo     app: mongodb
echo   ports:
echo     - name: mongodb
echo       protocol: TCP
echo       port: 27017
echo       targetPort: mongodb
echo ---
echo apiVersion: v1
echo kind: ConfigMap
echo metadata:
echo   name: mongodb-configmap
echo   namespace: %NAMESPACE%
echo data:
echo   database_url: "mongodb-service"
echo   database_host: "mongodb-service"
echo   database_port: "27017"
echo   database_uri: "mongodb://mongodb-service:27017"
) > "%DEPLOYMENT_FILES%\13-%NAMESPACE%-deployment.yaml"

REM Write the Mongo Express Deployment and Service manifests.
(
echo apiVersion: apps/v1
echo kind: Deployment
echo metadata:
echo   name: mongo-express-deployment
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: mongo-express
echo spec:
echo   replicas: 2
echo   selector:
echo     matchLabels:
echo       app: mongo-express
echo   template:
echo     metadata:
echo       labels:
echo         app: mongo-express
echo     spec:
echo       containers:
echo         - name: mongo-express
echo           image: mongo-express:1.0.2-20-alpine3.19
echo           imagePullPolicy: IfNotPresent
echo           ports:
echo             - name: http
echo               containerPort: 8081
echo               protocol: TCP
echo           env:
echo             - name: ME_CONFIG_MONGODB_ADMINUSERNAME
echo               valueFrom:
echo                 secretKeyRef:
echo                   name: mongodb-secret
echo                   key: mongo-root-username
echo             - name: ME_CONFIG_MONGODB_ADMINPASSWORD
echo               valueFrom:
echo                 secretKeyRef:
echo                   name: mongodb-secret
echo                   key: mongo-root-password
echo             - name: ME_CONFIG_MONGODB_SERVER
echo               valueFrom:
echo                 configMapKeyRef:
echo                   name: mongodb-configmap
echo                   key: database_url
echo             - name: ME_CONFIG_MONGODB_PORT
echo               value: "27017"
echo             - name: ME_CONFIG_MONGODB_ENABLE_ADMIN
echo               value: "true"
echo             - name: ME_CONFIG_BASICAUTH
echo               value: "true"
echo             - name: ME_CONFIG_BASICAUTH_USERNAME
echo               value: "admin"
echo             - name: ME_CONFIG_BASICAUTH_PASSWORD
echo               valueFrom:
echo                 secretKeyRef:
echo                   name: mongodb-secret
echo                   key: mongo-express-password
echo           startupProbe:
echo             tcpSocket:
echo               port: http
echo             periodSeconds: 10
echo             failureThreshold: 30
echo           readinessProbe:
echo             tcpSocket:
echo               port: http
echo             periodSeconds: 10
echo           livenessProbe:
echo             tcpSocket:
echo               port: http
echo             periodSeconds: 20
echo ---
echo apiVersion: v1
echo kind: Service
echo metadata:
echo   name: mongo-express-service
echo   namespace: %NAMESPACE%
echo   labels:
echo     app: mongo-express
echo spec:
echo   type: LoadBalancer
echo   selector:
echo     app: mongo-express
echo   ports:
echo     - name: http
echo       protocol: TCP
echo       port: 8081
echo       targetPort: http
) > "%DEPLOYMENT_FILES%\14-%NAMESPACE%-mongoexpress-deployment.yaml"

REM Deploy MongoDB.
echo Deploying MongoDB

REM Apply the Namespace manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\10-%NAMESPACE%-namespace.yaml" || exit /b 1

REM Apply the Secret manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\11-%NAMESPACE%-secret.yaml" || exit /b 1

REM Apply the PersistentVolumeClaim manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\12-%NAMESPACE%-pvc.yaml" || exit /b 1

REM Apply the Deployment manifest.
kubectl apply -f "%DEPLOYMENT_FILES%\13-%NAMESPACE%-deployment.yaml" || exit /b 1

REM Wait for the deployment rollout to complete.
kubectl rollout status deployment/mongodb-deployment -n %NAMESPACE% --timeout=%ROLLOUT_TIMEOUT% || exit /b 1

REM Deploy Mongo Express.
echo Deploying Mongo Express

REM Apply the Mongo Express Deployment and Service manifests.
kubectl apply -f "%DEPLOYMENT_FILES%\14-%NAMESPACE%-mongoexpress-deployment.yaml" || exit /b 1

REM Wait for the deployment rollout to complete.
kubectl rollout status deployment/mongo-express-deployment -n %NAMESPACE% --timeout=%ROLLOUT_TIMEOUT% || exit /b 1

REM Wait for the LoadBalancer service to receive an IP address.
kubectl wait service/mongo-express-service -n %NAMESPACE% --for=jsonpath="{.status.loadBalancer.ingress[0].ip}" --timeout=%LOAD_BALANCER_TIMEOUT% || exit /b 1

REM ------------------------------------------------------------------------------------------------------------
echo Display MongoDB and Mongo Express resources, LoadBalancer configuration, and HTTP access.
REM ------------------------------------------------------------------------------------------------------------

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # MongoDB and Mongo Express resources
echo # ------------------------------------------------------------------------------------------------------------
kubectl get all -n %NAMESPACE% || exit /b 1

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # MongoDB and Mongo Express pods and container images
echo # ------------------------------------------------------------------------------------------------------------
kubectl get pods -n %NAMESPACE% -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image"

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # MongoDB persistent storage
echo # ------------------------------------------------------------------------------------------------------------
kubectl get pvc mongodb-pvc -n %NAMESPACE%

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # Mongo Express LoadBalancer service
echo # ------------------------------------------------------------------------------------------------------------
kubectl get service mongo-express-service -n %NAMESPACE% -o wide

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # Mongo Express service endpoints
echo # ------------------------------------------------------------------------------------------------------------
kubectl get endpointslices -n %NAMESPACE% -l kubernetes.io/service-name=mongo-express-service

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # LoadBalancer IP address and service port
echo # ------------------------------------------------------------------------------------------------------------

REM Clear the previous LoadBalancer IP address and service port.
set "LB_IP="
set "LB_PORT="

REM Read the assigned LoadBalancer IP address.
for /f "delims=" %%I in ('kubectl get service mongo-express-service -n %NAMESPACE% -o jsonpath^="{.status.loadBalancer.ingress[0].ip}"') do set "LB_IP=%%I"

REM Read the exposed HTTP service port.
for /f "delims=" %%P in ('kubectl get service mongo-express-service -n %NAMESPACE% -o jsonpath^="{.spec.ports[0].port}"') do set "LB_PORT=%%P"

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo LoadBalancer IP Address : %LB_IP%
echo Service Port            : %LB_PORT%
echo # ------------------------------------------------------------------------------------------------------------

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # Test HTTP connectivity directly through the LoadBalancer IP
echo # ------------------------------------------------------------------------------------------------------------
echo curl -fv --max-time 15 --user admin:pass http://%LB_IP%:%LB_PORT%/

echo(
echo # ------------------------------------------------------------------------------------------------------------
echo # Mongo Express HTTP endpoint
echo # ------------------------------------------------------------------------------------------------------------
echo Mongo Express URL: http://%LB_IP%:%LB_PORT%/
echo Default login: admin:pass

REM Restore the calling environment.
endlocal
