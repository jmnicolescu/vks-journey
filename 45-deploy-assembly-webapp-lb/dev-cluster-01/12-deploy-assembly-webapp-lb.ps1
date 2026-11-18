#Requires -Version 7.0
#----------------+-------------------------------------------------------------------+
# Script Name    | 12-deploy-assembly-webapp-lb.ps1                                  |
# Updated        | 2026-11-18                                                        |
# Version        | 1.6                                                               |
# VCF Version    | 9.1.1                                                             |
# Description    | Deploy the Assembly WebApp with a LoadBalancer service.           |
#----------------+-------------------------------------------------------------------+

#----------------+-------------------------------------------------------------------+
# Requirement    | Details                                                           |
#----------------+-------------------------------------------------------------------+
# Runtime        | PowerShell 7.0 or later.                                          |
# Tools          | VCF CLI and kubectl available in PATH.                            |
# Authentication | Existing VCF context with credentials that can be refreshed.      |
# Access         | Workload cluster API connectivity.                                |
# Permissions    | Manage the application namespace and its resources.               |
# Configuration  | Set the target cluster name and application namespace.            |
# Infrastructure | VKS cluster with LoadBalancer support and container image access. |
# Files          | Write access to deployment-files in the current directory.        |
#----------------+-------------------------------------------------------------------+

# Stop when a PowerShell command fails; native commands below exit on failure.
$ErrorActionPreference = 'Stop'

$CLUSTER_NAME = 'dev-cluster-01'
$NAMESPACE = 'dev-assembly-lb'

$DEPLOYMENT_FILES = 'deployment-files'
$ROLLOUT_TIMEOUT = '300s'
$LOAD_BALANCER_TIMEOUT = '300s'

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
  name: ${NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
"@ | Set-Content -Path "$DEPLOYMENT_FILES/10-$($NAMESPACE)-namespace.yaml" -Encoding utf8

# Apply the namespace manifest.
kubectl apply -f "$DEPLOYMENT_FILES/10-$($NAMESPACE)-namespace.yaml" || $(exit $LASTEXITCODE)

# Write the deployment and LoadBalancer service manifest.
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: assembly-deployment
  namespace: $NAMESPACE
  labels:
    app: assembly-webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: assembly-webapp
  template:
    metadata:
      name: assembly-webapp-pod
      labels:
        app: assembly-webapp
    spec:
      containers:
      - name: assembly-webapp
        image: jmnicolescu/assembly-webapp:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: assembly-service
  namespace: $NAMESPACE
  labels:
    app: assembly-webapp
spec:
  type: LoadBalancer
  selector:
    app: assembly-webapp
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
"@ | Set-Content -Path "$DEPLOYMENT_FILES/11-$($NAMESPACE)-deployment.yaml" -Encoding utf8

# Apply the deployment and LoadBalancer service manifest.
kubectl apply -f "$DEPLOYMENT_FILES/11-$($NAMESPACE)-deployment.yaml" || $(exit $LASTEXITCODE)

# Wait for the deployment rollout to complete.
kubectl rollout status deployment/assembly-deployment -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || $(exit $LASTEXITCODE)

# Report that the deployment rollout completed.
Write-Host "Assembly WebApp deployment ready in namespace $NAMESPACE."

# Wait for the LoadBalancer service to receive an IP address.
kubectl wait service/assembly-service -n $NAMESPACE `
    --for='jsonpath={.status.loadBalancer.ingress[0].ip}' --timeout=$LOAD_BALANCER_TIMEOUT || $(exit $LASTEXITCODE)

# ------------------------------------------------------------------------------------------------------------
Write-Host "Display Assembly WebApp resources, LoadBalancer configuration, and HTTP access."
# ------------------------------------------------------------------------------------------------------------

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Assembly WebApp resources"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get all -n $NAMESPACE || $(exit $LASTEXITCODE)

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Assembly WebApp pods and container images"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get pods -n $NAMESPACE -o 'custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image' || $(exit $LASTEXITCODE)

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Assembly WebApp LoadBalancer service"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get service assembly-service -n $NAMESPACE -o wide

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Assembly WebApp service endpoints"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
kubectl get endpointslices -n $NAMESPACE -l kubernetes.io/service-name=assembly-service

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# LoadBalancer IP address and service port"
Write-Host "# ------------------------------------------------------------------------------------------------------------"

Write-Host "Read the assigned LoadBalancer IP address."
$LB_IP = kubectl get service assembly-service -n $NAMESPACE `
    -o 'jsonpath={.status.loadBalancer.ingress[0].ip}' || $(exit $LASTEXITCODE)

Write-Host "Read the exposed HTTP service port."
$LB_PORT = kubectl get service assembly-service -n $NAMESPACE `
    -o 'jsonpath={.spec.ports[0].port}'

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "LoadBalancer IP Address : $LB_IP"
Write-Host "Service Port            : $LB_PORT"
Write-Host "# ------------------------------------------------------------------------------------------------------------"

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Test HTTP connectivity directly through the LoadBalancer IP"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "curl -fv --max-time 15 http://$($LB_IP):$($LB_PORT)/"

Write-Host
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "# Assembly WebApp HTTP endpoint"
Write-Host "# ------------------------------------------------------------------------------------------------------------"
Write-Host "Assembly WebApp URL: http://$($LB_IP):$($LB_PORT)/"
