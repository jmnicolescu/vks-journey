#!/bin/bash
#----------------+-------------------------------------------------------------------+
# Script Name    | 02-deploy-assembly-webapp-lb.sh                                   |
# Updated        | 2026-11-18                                                        |
# Version        | 1.8                                                               |
# VCF Version    | 9.1.1                                                             |
# Description    | Deploy the Assembly WebApp with a LoadBalancer service.           |
#----------------+-------------------------------------------------------------------+

#----------------+-------------------------------------------------------------------+
# Requirement    | Details                                                           |
#----------------+-------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                           |
# Tools          | VCF CLI and kubectl available in PATH.                            |
# Authentication | Existing VCF context with credentials that can be refreshed.      |
# Access         | Workload cluster API connectivity.                                |
# Permissions    | Manage the application namespace and its resources.               |
# Configuration  | Set the target cluster name and application namespace.            |
# Infrastructure | VKS cluster with LoadBalancer support and container image access. |
# Files          | Write access to deployment-files in the current directory.        |
#----------------+-------------------------------------------------------------------+

echo "Stop when a command fails."
set -e

CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-lb

DEPLOYMENT_FILES=deployment-files
ROLLOUT_TIMEOUT=300s
LOAD_BALANCER_TIMEOUT=300s

echo "Refresh workload cluster authentication."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Create the deployment files directory."
mkdir -p ${DEPLOYMENT_FILES}

# Kubernetes defines three Pod Security Standards:
#------------+----------------------------------------------------------------------+----------+
# Level      | Description                                                          | Security |
#------------+----------------------------------------------------------------------+----------+
# privileged | Unrestricted policy; permits privileged containers and configurations| Low      |
#------------+----------------------------------------------------------------------+----------+
# baseline   | Prevents known privilege escalation risks; supports common apps      | Medium   |
#------------+----------------------------------------------------------------------+----------+
# restricted | Enforces stronger container security controls                        | High     |
#------------+----------------------------------------------------------------------+----------+

echo "Create the application namespace with privileged Pod Security, auditing and warnings enforcement."
cat << EOF > "${DEPLOYMENT_FILES}/10-${NAMESPACE}-namespace.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF

echo "Apply the namespace manifest."
kubectl apply -f ${DEPLOYMENT_FILES}/10-${NAMESPACE}-namespace.yaml

echo "Write the deployment and LoadBalancer service manifest."
cat << EOF > ${DEPLOYMENT_FILES}/11-${NAMESPACE}-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: assembly-deployment
  namespace: ${NAMESPACE}
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
  namespace: ${NAMESPACE}
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
EOF

echo "Apply the deployment and LoadBalancer service manifest."
kubectl apply -f ${DEPLOYMENT_FILES}/11-${NAMESPACE}-deployment.yaml

echo "Wait for the deployment rollout to complete."
kubectl rollout status deployment/assembly-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Report that the deployment rollout completed."
echo "Assembly WebApp deployment ready in namespace ${NAMESPACE}."

echo "Wait for the LoadBalancer service to receive an IP address."
kubectl wait service/assembly-service -n ${NAMESPACE} \
    --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' --timeout=${LOAD_BALANCER_TIMEOUT}

# ------------------------------------------------------------------------------------------------------------
echo "Display Assembly WebApp resources, LoadBalancer configuration, and HTTP access."
# ------------------------------------------------------------------------------------------------------------

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp resources"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get all -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp pods and container images"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[*].image'

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp LoadBalancer service"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get service assembly-service -n ${NAMESPACE} -o wide

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp service endpoints"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get endpointslices -n ${NAMESPACE} -l kubernetes.io/service-name=assembly-service

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# LoadBalancer IP address and service port"
echo "# ------------------------------------------------------------------------------------------------------------"

echo "Read the assigned LoadBalancer IP address."
LB_IP=$(kubectl get service assembly-service -n ${NAMESPACE} \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Read the exposed HTTP service port."
LB_PORT=$(kubectl get service assembly-service -n ${NAMESPACE} \
    -o jsonpath='{.spec.ports[0].port}')

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "LoadBalancer IP Address : ${LB_IP}"
echo "Service Port            : ${LB_PORT}"
echo "# ------------------------------------------------------------------------------------------------------------"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Test HTTP connectivity directly through the LoadBalancer IP"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "curl -fv --max-time 15 http://${LB_IP}:${LB_PORT}/"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp HTTP endpoint"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Assembly WebApp URL: http://${LB_IP}:${LB_PORT}/"
