#!/bin/bash
#----------------+-----------------------------------------------------------------------+
# Script Name    | 02-deploy-assembly-webapp-static-gateway.sh                           |
# Updated        | 2026-11-18                                                            |
# Version        | 1.10                                                                  |
# VCF Version    | 9.1.1                                                                 |
# Description    | Deploy Assembly through Contour Gateway API with HTTPS.               |
#----------------+-----------------------------------------------------------------------+

#----------------+-----------------------------------------------------------------------+
# Requirement    | Details                                                               |
#----------------+-----------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                               |
# Tools          | VCF CLI, kubectl and jq; curl for the manual HTTPS test.              |
# Authentication | Existing VCF context with refreshable credentials.                    |
# Access         | Workload cluster API connectivity.                                    |
# Permissions    | Manage app resources and HTTPRoutes; read the shared Gateway.         |
# Configuration  | Set cluster, namespace, Gateway names and application FQDN.           |
# Infrastructure | Existing Contour Gateway with http and https listeners.               |
# Files          | Gateway TLS certificate must cover the application FQDN.              |
# Output         | Write access to deployment-files beside the script.                   |
# HTTPS          | Application DNS record and issuing CA trusted locally.                |
# Effect         | Deploys app resources and routes using the existing Gateway.          |
#----------------+-----------------------------------------------------------------------+

set -eo pipefail

# Editable lab inputs: set these names and the FQDN for the target environment.
CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-assembly-contour
APP_FQDN=qa-assembly-contour.platformlab.vcf

GATEWAY_NAME=contour-gateway
GATEWAY_NAMESPACE=tanzu-system-ingress

ROLLOUT_TIMEOUT=300s
LOAD_BALANCER_TIMEOUT=300s

echo "Resolve the script directory, including paths containing spaces."
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

echo "Create the deployment manifest directory."
mkdir -p "${DEPLOYMENT_FILES}"

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
# vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

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
cat << EOF > "${DEPLOYMENT_FILES}/11-${NAMESPACE}-namespace.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF

echo "Write the Assembly deployment and ClusterIP Service manifest."
cat << EOF > "${DEPLOYMENT_FILES}/12-${NAMESPACE}-deployment.yaml"
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
  type: ClusterIP
  selector:
    app: assembly-webapp
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF

echo "Write the HTTPS route and HTTP-to-HTTPS redirect for the application."
cat << EOF > "${DEPLOYMENT_FILES}/13-${NAMESPACE}-httproute.yaml"
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: assembly-httproute
  namespace: ${NAMESPACE}
spec:
  parentRefs:
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
      sectionName: https
  hostnames:
    - ${APP_FQDN}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: assembly-service
          port: 8080
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: assembly-http-redirect
  namespace: ${NAMESPACE}
spec:
  parentRefs:
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
      sectionName: http
  hostnames:
    - ${APP_FQDN}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
EOF

echo "Create or update the application namespace."
kubectl apply -f "${DEPLOYMENT_FILES}/11-${NAMESPACE}-namespace.yaml"

echo "Apply the application deployment and ClusterIP Service."
kubectl apply -f "${DEPLOYMENT_FILES}/12-${NAMESPACE}-deployment.yaml"

echo "Apply the HTTPS route and HTTP redirect."
kubectl apply -f "${DEPLOYMENT_FILES}/13-${NAMESPACE}-httproute.yaml"

echo "Wait for the application deployment rollout."
kubectl rollout status deployment/assembly-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Wait for the shared Gateway to receive an address."
kubectl wait gateway/${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} \
    --for=jsonpath='{.status.addresses[0].value}' --timeout=${LOAD_BALANCER_TIMEOUT}

# ------------------------------------------------------------------------------------------------------------
echo "Display Assembly resources, Gateway API configuration, and a manual HTTPS test command."
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
echo "# Contour Gateway API resources"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE}
kubectl get httproutes -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Contour Gateway listener status"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o json | \
    jq '.status.listeners[] | {
        name,
        attachedRoutes,
        conditions: [.conditions[] | {type, status}]
    }'

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp HTTPRoute conditions"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl describe httproute assembly-httproute assembly-http-redirect -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Gateway IP address and DNS configuration"
echo "# ------------------------------------------------------------------------------------------------------------"

echo "Retrieve the Gateway IP address."
LB_IP=$(kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} \
    -o jsonpath='{.status.addresses[0].value}')

echo "Display the required DNS configuration."
echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Gateway IP Address : ${LB_IP}"
echo "DNS A Record       : ${APP_FQDN} -> ${LB_IP}"
echo "# ------------------------------------------------------------------------------------------------------------"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Manual HTTPS test through the Gateway IP"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Bypass DNS while preserving the FQDN for TLS SNI and certificate validation."
echo "curl -fkv --max-time 15 --resolve ${APP_FQDN}:443:${LB_IP} https://${APP_FQDN}/ "

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Assembly WebApp HTTPS endpoint"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Assembly WebApp URL: https://${APP_FQDN}/"
echo
