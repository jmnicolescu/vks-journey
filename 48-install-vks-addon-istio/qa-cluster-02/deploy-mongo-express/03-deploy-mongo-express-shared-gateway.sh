#!/bin/bash
#----------------+------------------------------------------------------------------+
# Script Name    | 03-deploy-mongo-express-shared-gateway.sh                        |
# Updated        | 2026-11-17                                                       |
# Version        | 1.0                                                              |
# VCF Version    | 9.1.1                                                            |
# Description    | Deploy MongoDB and Mongo Express through Istio HTTPS.            |
#----------------+------------------------------------------------------------------+

#----------------+------------------------------------------------------------------+
# Requirement    | Details                                                          |
#----------------+------------------------------------------------------------------+
# Runtime        | Bash on macOS or Linux.                                          |
# Tools          | VCF CLI, kubectl, jq, curl and nslookup in PATH.                 |
# Authentication | Existing VCF context with refreshable credentials.               |
# Access         | Workload cluster API connectivity.                               |
# Permissions    | Manage app namespace resources and HTTPRoutes.                   |
# Configuration  | Set cluster, namespace, Gateway names and application FQDN.      |
# Infrastructure | Existing Istio Gateway with matching HTTP/HTTPS listeners.       |
# Output         | Write access to deployment-files beside the script.              |
# HTTPS          | Application DNS record and issuing CA trusted locally.           |
# Effect         | Uses the existing shared Gateway without changing its listeners. |
# Storage        | Configured storage class with dynamic volume provisioning.       |
# Images         | MongoDB 8.0 and Mongo Express 1.0.2.                             |
#----------------+------------------------------------------------------------------+
set -e -o pipefail

# Editable lab inputs: set these names and the FQDN for the target environment.
CLUSTER_NAME=qa-cluster-02
NAMESPACE=qa-mongodb-istio
APP_FQDN=qa-mongo-express-istio.platformlab.vcf
STORAGE_CLASS=vsan-default-storage-policy

ROLLOUT_TIMEOUT=300s
LOAD_BALANCER_TIMEOUT=300s

# Using a shared Istio Gateway API resource with HTTP and HTTPS.
GATEWAY_NAME=istio-gateway
GATEWAY_NAMESPACE=istio-gateway

echo "Resolve the script directory, including paths containing spaces."
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Create the deployment manifest directory."
mkdir -p "${DEPLOYMENT_FILES}"

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

echo "Write the Secret manifest."
cat << EOF > "${DEPLOYMENT_FILES}/12-${NAMESPACE}-secret.yaml"
apiVersion: v1
kind: Secret
metadata:
    name: mongodb-secret
    namespace: ${NAMESPACE}
type: Opaque
data:
    mongo-root-username: YWRtaW4=
    mongo-root-password: c3VwZXJzZWNyZXQ=
    mongo-express-password: cGFzcw==
EOF

echo "Write the PersistentVolumeClaim manifest."
cat << EOF > "${DEPLOYMENT_FILES}/13-${NAMESPACE}-pvc.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ${STORAGE_CLASS}
EOF

echo "Write the MongoDB Deployment, Service, and ConfigMap manifests."
cat << EOF > "${DEPLOYMENT_FILES}/14-${NAMESPACE}-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-deployment
  namespace: ${NAMESPACE}
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
          image: mongo:8.0
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
  namespace: ${NAMESPACE}
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
  namespace: ${NAMESPACE}
data:
  database_url: "mongodb-service"
  database_host: "mongodb-service"
  database_port: "27017"
  database_uri: "mongodb://mongodb-service:27017"
EOF

echo "Write the Mongo Express Deployment and Service manifests."
cat << EOF > "${DEPLOYMENT_FILES}/15-${NAMESPACE}-mongoexpress-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo-express-deployment
  namespace: ${NAMESPACE}
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
          image: mongo-express:1.0.2
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
  namespace: ${NAMESPACE}
  labels:
    app: mongo-express
spec:
  type: ClusterIP
  selector:
    app: mongo-express
  ports:
    - name: http
      protocol: TCP
      port: 8081
      targetPort: http
EOF

echo "Write the HTTPS route and HTTP-to-HTTPS redirect for the application."
cat << EOF > "${DEPLOYMENT_FILES}/16-${NAMESPACE}-httproute.yaml"
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mongo-express-httproute
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
        - name: mongo-express-service
          port: 8081
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mongo-express-http-redirect
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

echo "Apply the MongoDB Secret."
kubectl apply -f "${DEPLOYMENT_FILES}/12-${NAMESPACE}-secret.yaml"

echo "Apply the MongoDB PersistentVolumeClaim."
kubectl apply -f "${DEPLOYMENT_FILES}/13-${NAMESPACE}-pvc.yaml"

echo "Apply the MongoDB deployment, Service and ConfigMap."
kubectl apply -f "${DEPLOYMENT_FILES}/14-${NAMESPACE}-deployment.yaml"

echo "Wait for the MongoDB deployment rollout."
kubectl rollout status deployment/mongodb-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Apply the Mongo Express deployment and ClusterIP Service."
kubectl apply -f "${DEPLOYMENT_FILES}/15-${NAMESPACE}-mongoexpress-deployment.yaml"

echo "Apply the HTTPS route and HTTP redirect."
kubectl apply -f "${DEPLOYMENT_FILES}/16-${NAMESPACE}-httproute.yaml"

echo "Wait for the application deployment rollout."
kubectl rollout status deployment/mongo-express-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Wait for Istio to program the shared Gateway."
kubectl wait gateways.gateway.networking.k8s.io/${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} \
    --for=condition=Programmed --timeout=${LOAD_BALANCER_TIMEOUT}

echo "Wait for the shared Gateway to receive an address."
kubectl wait gateways.gateway.networking.k8s.io/${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} \
    --for=jsonpath='{.status.addresses[0].value}' --timeout=${LOAD_BALANCER_TIMEOUT}

# ------------------------------------------------------------------------------------------------------------
echo "Display Mongo Express resources, Gateway API configuration, and test HTTPS connectivity."
# ------------------------------------------------------------------------------------------------------------

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express resources"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get all -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express pods and container images"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[*].image'

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Istio Gateway API resources"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get gateways.gateway.networking.k8s.io ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE}
kubectl get httproutes -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Istio Gateway listener status"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get gateways.gateway.networking.k8s.io ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o json | \
    jq '.status.listeners[] | {
        name,
        attachedRoutes,
        conditions: [.conditions[] | {type, status}]
    }'

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express HTTPRoute conditions"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl describe httproute mongo-express-httproute mongo-express-http-redirect -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Gateway IP address and DNS configuration"
echo "# ------------------------------------------------------------------------------------------------------------"

echo "Retrieve the Gateway IP address."
LB_IP=$(kubectl get gateways.gateway.networking.k8s.io ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} \
    -o jsonpath='{.status.addresses[0].value}')

echo "Display the required DNS configuration."
echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Gateway IP Address : ${LB_IP}"
echo "DNS A Record       : ${APP_FQDN} -> ${LB_IP}"
echo "# ------------------------------------------------------------------------------------------------------------"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Test HTTPS connectivity directly through the Gateway IP"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Bypass DNS while preserving the FQDN for TLS SNI and certificate validation."
echo "curl -fkv --max-time 15 --resolve ${APP_FQDN}:443:${LB_IP} https://${APP_FQDN}/ "

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express HTTPS endpoint"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Mongo Express URL: https://${APP_FQDN}/"
echo
