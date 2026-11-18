#!/bin/bash
#-------------+---------------------------------------------------------------+
# Script Name | 02-deploy-mongo-express-lb.sh                                 |
# Updated     | 2026-11-18                                                    |
# Version     | 1.11                                                          |
# VCF Version | 9.1.1.0-545627-2026-09                                        |
# Description | Deploy MongoDB and Mongo Express; report LoadBalancer access. |
#-------------+---------------------------------------------------------------+

#-------------+---------------------------------------------------------------+
# Requirement | Details                                                       |
#-------------+---------------------------------------------------------------+
# Runtime     | Linux or macOS with Bash.                                     |
# Tools       | VCF CLI and kubectl in PATH.                                  |
# Access      | Authenticated VCF context and workload Kubernetes API access. |
# Inputs      | Set the target cluster and application namespace.             |
# Permissions | Create and update namespaces and application resources.       |
# Storage     | Configured storage class and dynamic volume provisioning.     |
# Network     | Cluster image pulls and LoadBalancer provisioning.            |
# Files       | Write access to deployment-files beside this script.          |
# Images      | MongoDB 9.0.8; Mongo Express 1.0.2 (Node 20, Alpine 3.19).    |
#-------------+---------------------------------------------------------------+

# ------------------------------------------------------------------------------------------------------
# Mongo DB default login admin:supersecret. They are Base64 encoded.
# Mongo Express default login: admin:pass
# ------------------------------------------------------------------------------------------------------

echo "Stop when a command fails."
set -e

CLUSTER_NAME=dev-cluster-01
NAMESPACE=dev-mongodb-lb

STORAGE_CLASS=vsan-default-storage-policy
ROLLOUT_TIMEOUT=300s
LOAD_BALANCER_TIMEOUT=300s

echo "Resolve the script directory for generated deployment files."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload Kubernetes context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Create the deployment files directory."
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

echo "Write the Secret manifest."
cat << EOF > "${DEPLOYMENT_FILES}/11-${NAMESPACE}-secret.yaml"
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
cat << EOF > "${DEPLOYMENT_FILES}/12-${NAMESPACE}-pvc.yaml"
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
cat << EOF > "${DEPLOYMENT_FILES}/13-${NAMESPACE}-deployment.yaml"
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
cat << EOF > "${DEPLOYMENT_FILES}/14-${NAMESPACE}-mongoexpress-deployment.yaml"
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
  namespace: ${NAMESPACE}
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
EOF

echo "Deploying MongoDB"

echo "Apply the Namespace manifest."
kubectl apply -f "${DEPLOYMENT_FILES}/10-${NAMESPACE}-namespace.yaml"

echo "Apply the Secret manifest."
kubectl apply -f "${DEPLOYMENT_FILES}/11-${NAMESPACE}-secret.yaml"

echo "Apply the PersistentVolumeClaim manifest."
kubectl apply -f "${DEPLOYMENT_FILES}/12-${NAMESPACE}-pvc.yaml"

echo "Apply the Deployment manifest."
kubectl apply -f "${DEPLOYMENT_FILES}/13-${NAMESPACE}-deployment.yaml"

echo "Wait for the deployment rollout to complete."
kubectl rollout status deployment/mongodb-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Deploying Mongo Express"

echo "Apply the Mongo Express Deployment and Service manifests."
kubectl apply -f "${DEPLOYMENT_FILES}/14-${NAMESPACE}-mongoexpress-deployment.yaml"

echo "Wait for the deployment rollout to complete."
kubectl rollout status deployment/mongo-express-deployment -n ${NAMESPACE} --timeout=${ROLLOUT_TIMEOUT}

echo "Wait for the LoadBalancer service to receive an IP address."
kubectl wait service/mongo-express-service -n ${NAMESPACE} \
    --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' --timeout=${LOAD_BALANCER_TIMEOUT}

# ------------------------------------------------------------------------------------------------------------
echo "Display MongoDB and Mongo Express resources, LoadBalancer configuration, and HTTP access."
# ------------------------------------------------------------------------------------------------------------

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# MongoDB and Mongo Express resources"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get all -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# MongoDB and Mongo Express pods and container images"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get pods -n ${NAMESPACE} -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[*].image'

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# MongoDB persistent storage"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get pvc mongodb-pvc -n ${NAMESPACE}

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express LoadBalancer service"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get service mongo-express-service -n ${NAMESPACE} -o wide

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express service endpoints"
echo "# ------------------------------------------------------------------------------------------------------------"
kubectl get endpointslices -n ${NAMESPACE} -l kubernetes.io/service-name=mongo-express-service

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# LoadBalancer IP address and service port"
echo "# ------------------------------------------------------------------------------------------------------------"

echo "Read the assigned LoadBalancer IP address."
LB_IP=$(kubectl get service mongo-express-service -n ${NAMESPACE} \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Read the exposed HTTP service port."
LB_PORT=$(kubectl get service mongo-express-service -n ${NAMESPACE} \
    -o jsonpath='{.spec.ports[?(@.name=="http")].port}')

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "LoadBalancer IP Address : ${LB_IP}"
echo "Service Port            : ${LB_PORT}"
echo "# ------------------------------------------------------------------------------------------------------------"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Test HTTP connectivity directly through the LoadBalancer IP"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "curl -fv --max-time 15 --user admin:pass http://${LB_IP}:${LB_PORT}/"

echo
echo "# ------------------------------------------------------------------------------------------------------------"
echo "# Mongo Express HTTP endpoint"
echo "# ------------------------------------------------------------------------------------------------------------"
echo "Mongo Express URL: http://${LB_IP}:${LB_PORT}/"
echo "Default login: admin:pass"
