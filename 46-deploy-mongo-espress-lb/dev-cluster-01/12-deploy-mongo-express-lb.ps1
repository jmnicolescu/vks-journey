#Requires -Version 7.0
#-------------+---------------------------------------------------------------+
# Script Name | 12-deploy-mongo-express-lb.ps1                                |
# Updated     | 2026-11-18                                                    |
# Version     | 1.4                                                           |
# VCF Version | 9.1.1.0-545627-2026-09                                        |
# Description | Deploy MongoDB and Mongo Express; report LoadBalancer access. |
#-------------+---------------------------------------------------------------+

#-------------+---------------------------------------------------------------+
# Requirement | Details                                                       |
#-------------+---------------------------------------------------------------+
# Runtime     | PowerShell 7.0+ with compatible VCF CLI and kubectl binaries. |
# Tools       | VCF CLI and kubectl in PATH.                                  |
# Access      | Authenticated VCF context and workload Kubernetes API access. |
# Inputs      | Set the target cluster and application namespace.             |
# Permissions | Create and update namespaces and application resources.       |
# Storage     | Configured storage class and dynamic volume provisioning.     |
# Network     | Cluster image pulls and LoadBalancer provisioning.            |
# Files       | Write access to deployment-files beside this script.          |
# Images      | MongoDB 9.0.8; Mongo Express 1.0.2 (Node 20, Alpine 3.19).    |
#-------------+---------------------------------------------------------------+

# Stop when a PowerShell command fails; native commands below exit on failure.
$ErrorActionPreference = 'Stop'

$CLUSTER_NAME = 'dev-cluster-01'
$NAMESPACE = 'dev-mongodb-lb'

$STORAGE_CLASS = 'vsan-default-storage-policy'
$ROLLOUT_TIMEOUT = '300s'
$LOAD_BALANCER_TIMEOUT = '300s'

# Resolve the deployment files directory beside this script.
$DEPLOYMENT_FILES = Join-Path -Path $PSScriptRoot -ChildPath deployment-files

# Refresh workload cluster authentication.
vcf context refresh $CLUSTER_NAME || $(exit $LASTEXITCODE)

# Select the workload Kubernetes context.
kubectl config use-context "$($CLUSTER_NAME):$CLUSTER_NAME" || $(exit $LASTEXITCODE)

# Create the deployment files directory.
New-Item -ItemType Directory -Path $DEPLOYMENT_FILES -Force | Out-Null

# Create the application namespace with privileged Pod Security, auditing and warnings enforcement.
@"
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
"@ | Set-Content -Path "$DEPLOYMENT_FILES/10-$($NAMESPACE)-namespace.yaml" -Encoding utf8

# Write the Secret manifest.
@"
apiVersion: v1
kind: Secret
metadata:
    name: mongodb-secret
    namespace: $NAMESPACE
type: Opaque
data:
    mongo-root-username: YWRtaW4=
    mongo-root-password: c3VwZXJzZWNyZXQ=
    mongo-express-password: cGFzcw==
"@ | Set-Content -LiteralPath "$DEPLOYMENT_FILES/11-$NAMESPACE-secret.yaml" -Encoding utf8

# Write the PersistentVolumeClaim manifest.
@"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: $STORAGE_CLASS
"@ | Set-Content -LiteralPath "$DEPLOYMENT_FILES/12-$NAMESPACE-pvc.yaml" -Encoding utf8

# Write the MongoDB Deployment, Service, and ConfigMap manifests.
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-deployment
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:9.0.8
          imagePullPolicy: IfNotPresent
          ports:
            - name: mongodb
              containerPort: 27017
              protocol: TCP
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: mongo-root-username
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: mongo-root-password
          volumeMounts:
            - name: mongodb-storage
              mountPath: /data/db
          startupProbe:
            tcpSocket:
              port: mongodb
            periodSeconds: 10
            failureThreshold: 30
          readinessProbe:
            tcpSocket:
              port: mongodb
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: mongodb
            initialDelaySeconds: 30
            periodSeconds: 20
      volumes:
        - name: mongodb-storage
          persistentVolumeClaim:
            claimName: mongodb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  type: ClusterIP
  selector:
    app: mongodb
  ports:
    - name: mongodb
      protocol: TCP
      port: 27017
      targetPort: mongodb
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-configmap
  namespace: $NAMESPACE
data:
  database_url: "mongodb-service"
  database_host: "mongodb-service"
  database_port: "27017"
  database_uri: "mongodb://mongodb-service:27017"
"@ | Set-Content -LiteralPath "$DEPLOYMENT_FILES/13-$NAMESPACE-deployment.yaml" -Encoding utf8

# Write the Mongo Express Deployment and Service manifests.
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo-express-deployment
  namespace: $NAMESPACE
  labels:
    app: mongo-express
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mongo-express
  template:
    metadata:
      labels:
        app: mongo-express
    spec:
      containers:
        - name: mongo-express
          image: mongo-express:1.0.2-20-alpine3.19
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8081
              protocol: TCP
          env:
            - name: ME_CONFIG_MONGODB_ADMINUSERNAME
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: mongo-root-username
            - name: ME_CONFIG_MONGODB_ADMINPASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: mongo-root-password
            - name: ME_CONFIG_MONGODB_SERVER
              valueFrom:
                configMapKeyRef:
                  name: mongodb-configmap
                  key: database_url
            - name: ME_CONFIG_MONGODB_PORT
              value: "27017"
            - name: ME_CONFIG_MONGODB_ENABLE_ADMIN
              value: "true"
            - name: ME_CONFIG_BASICAUTH
              value: "true"
            - name: ME_CONFIG_BASICAUTH_USERNAME
              value: "admin"
            - name: ME_CONFIG_BASICAUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: mongo-express-password
          startupProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
            failureThreshold: 30
          readinessProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: http
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: mongo-express-service
  namespace: $NAMESPACE
  labels:
    app: mongo-express
spec:
  type: LoadBalancer
  selector:
    app: mongo-express
  ports:
    - name: http
      protocol: TCP
      port: 8081
      targetPort: http
"@ | Set-Content -LiteralPath "$DEPLOYMENT_FILES/14-$NAMESPACE-mongoexpress-deployment.yaml" -Encoding utf8

# Deploy MongoDB.
Write-Host "Deploying MongoDB"

# Apply the Namespace manifest.
kubectl apply -f "$DEPLOYMENT_FILES/10-$NAMESPACE-namespace.yaml" || $(exit $LASTEXITCODE)

# Apply the Secret manifest.
kubectl apply -f "$DEPLOYMENT_FILES/11-$NAMESPACE-secret.yaml" || $(exit $LASTEXITCODE)

# Apply the PersistentVolumeClaim manifest.
kubectl apply -f "$DEPLOYMENT_FILES/12-$NAMESPACE-pvc.yaml" || $(exit $LASTEXITCODE)

# Apply the Deployment manifest.
kubectl apply -f "$DEPLOYMENT_FILES/13-$NAMESPACE-deployment.yaml" || $(exit $LASTEXITCODE)

# Wait for the deployment rollout to complete.
kubectl rollout status deployment/mongodb-deployment -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || $(exit $LASTEXITCODE)

# Deploy Mongo Express.
Write-Host "Deploying Mongo Express"

# Apply the Mongo Express Deployment and Service manifests.
kubectl apply -f "$DEPLOYMENT_FILES/14-$NAMESPACE-mongoexpress-deployment.yaml" || $(exit $LASTEXITCODE)

# Wait for the deployment rollout to complete.
kubectl rollout status deployment/mongo-express-deployment -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || $(exit $LASTEXITCODE)

# Wait for the LoadBalancer service to receive an IP address.
kubectl wait service/mongo-express-service -n $NAMESPACE `
    --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' --timeout=$LOAD_BALANCER_TIMEOUT || $(exit $LASTEXITCODE)

# ------------------------------------------------------------------------------------------------------------
Write-Host "Display MongoDB and Mongo Express resources, LoadBalancer configuration, and HTTP access."
# ------------------------------------------------------------------------------------------------------------

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# MongoDB and Mongo Express resources"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get all -n $NAMESPACE || $(exit $LASTEXITCODE)

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# MongoDB and Mongo Express pods and container images"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get pods -n $NAMESPACE -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[*].image'

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# MongoDB persistent storage"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get pvc mongodb-pvc -n $NAMESPACE

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Mongo Express LoadBalancer service"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get service mongo-express-service -n $NAMESPACE -o wide

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Mongo Express service endpoints"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get endpointslices -n $NAMESPACE -l kubernetes.io/service-name=mongo-express-service

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# LoadBalancer IP address and service port"
Write-Host "# ------------------------------------------------------------------------------------------------------------"

# Read the assigned LoadBalancer IP address.
$LB_IP = kubectl get service mongo-express-service -n $NAMESPACE `
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || $(exit $LASTEXITCODE)

# Read the exposed HTTP service port.
$LB_PORT = kubectl get service mongo-express-service -n $NAMESPACE `
    -o jsonpath='{.spec.ports[0].port}'

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "LoadBalancer IP Address : $($LB_IP)"
Write-Host "Service Port            : $LB_PORT"
Write-Host "# ------------------------------------------------------------------------------------------------------------"

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Test HTTP connectivity directly through the LoadBalancer IP"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "Invoke-WebRequest -Uri http://$($LB_IP):$LB_PORT/ -Authentication Basic -Credential (Get-Credential -UserName admin -Message 'Mongo Express login') -AllowUnencryptedAuthentication -TimeoutSec 15"

Write-Host ""
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Mongo Express HTTP endpoint"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "Mongo Express URL: http://$($LB_IP):$LB_PORT/"
Write-Host "Default login: admin:pass"
