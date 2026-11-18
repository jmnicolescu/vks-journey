#!/bin/bash
#-------------+-------------------------------------------------------------------+
# Script Name | 10-install-istio-addon-vcf-cli.sh                                 |
# Updated     | 2026-11-16                                                        |
# Version     | 1.17                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                            |
# Description | Install Istio and configure Gateway API with a requested IP.      |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Tools       | VCF CLI 9.1.1, kubectl and standard shell utilities.              |
# Access      | Existing authenticated Supervisor and workload contexts.          |
# Inputs      | Set context, cluster, Supervisor namespace and add-on release.    |
# Permissions | Install add-ons; create Gateway resources; read/watch status.     |
# Network     | API access, package image pulls and LoadBalancer provisioning.    |
# Files       | Write access to deployment-files beside the script.               |
# Behavior    | Changes context; stops on failure; waits for Gateway Programmed.  |
#-------------+-------------------------------------------------------------------+

# Istio deployment sequence
#------+----------------------------------+------------------------------------------------------+
# Step | Component                        | Action                                               |
#------+----------------------------------+------------------------------------------------------+
# 1    | Istio Add-on                     | Install Istio using VCF CLI.                         |
# 2    | Istio Control Plane              | Verify istiod, CNI, and support pods are running.    |
# 3    | GatewayClass                     | Verify the automatically created Istio GatewayClass. |
# 4    | Gateway Namespace                | Create the ${GATEWAY_NAMESPACE} namespace.                  |
# 5    | Gateway Resource                 | Create the Istio Gateway API resource.               |
# 6    | Envoy / LoadBalancer             | Verify Envoy deployment and external IP assignment.  |
# 7    | Application / Service            | Deploy the application and Kubernetes Service.       |
# 8    | HTTPRoute                        | Create an HTTPRoute referencing the Istio Gateway.   |
# 9    | Validation                       | Test HTTP routing through the Gateway IP address.    |
#------+----------------------------------+------------------------------------------------------+
# set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02

# Set the upstream Istio version to install
ISTIO_RELEASE=istio.kubernetes.vmware.com.1.30.0-vmware.1-vks.1

READY_TIMEOUT=10m
# Static LoadBalancer IP request — subject to VKS LoadBalancer provider support
# The Gateway API specification identifies spec.addresses as an Extended Support feature rather than mandatory Core Support
ENVOY_LB_IP=10.55.16.107

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates
mkdir -p "${DEPLOYMENT_FILES}"

APP_FQDN=wildcard.platformlab.vcf
SERVER_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${APP_FQDN}.key
SERVER_CERTIFICATE_CHAIN_PATH=${CERTIFICATES_DIR}/${APP_FQDN}.cer.plusCA

GATEWAY_NAME=istio-gateway
GATEWAY_NAMESPACE=istio-gateway

# ------------------------------------------------------------------------------------------------------------
# Install Istio Addon using VCF CLI
#
# NAMESPACE           vmware-system-vks-public
# ADDONNAME           istio
# VERSION             1.30.0+vmware.1-vks.1
# ADDON-RELEASE-NAME  istio.kubernetes.vmware.com.1.30.0-vmware.1-vks.1
# PACKAGE             istio.kubernetes.vmware.com.1.30.0-vmware.1-vks.1  
# ------------------------------------------------------------------------------------------------------------
 
echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Check the pinned Istio release before installation."
vcf addon available-releases get ${ISTIO_RELEASE}

echo "Export the values from the exact istio release to be installed."
vcf addon available-releases get ${ISTIO_RELEASE} \
    --values-config-file-output "${DEPLOYMENT_FILES}/istio-default-data-values.yaml"

# ----------------------------------+---------------+------------------------------------------------+                                                                                       |
# Recommended Istio deployment settings                                                              |
#-----------------------------------+---------------+------------------------------------------------+
# Setting                           | Recommended   | Purpose                                        |
#-----------------------------------+---------------+------------------------------------------------+
# ambientMode.enabled               | false         | Use traditional sidecar mesh.                  |
# enableGatewayAPIInference         | false         | AI inference extension not required.           |
# enableStrictMTLS                  | false         | Disable strict mTLS initially.                 |
# gateways.ingress.enabled          | false         | Disable traditional Istio ingress gateway.     |
# gateways.egress.enabled           | false         | Disable dedicated egress gateway.              |
# istioCNI.enabled                  | true          | Enable CNI-based traffic interception.         |
# meshConfig.accessLogFile          | /dev/stdout   | Enable Envoy access logging.                   |
# meshConfig.enablePrometheusMerge  | true          | Merge application and Envoy metrics.           |
# meshConfig.enableTracing          | false         | Enable later with a tracing backend.           |
# pilot.replicas                    | 2             | Deploy two Istio control-plane replicas.       |
#-----------------------------------+---------------+------------------------------------------------+

cat << 'EOF' > "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-api-data-values.yaml"
# --------------------------------------------------------------------------------------------------
# VCF 9.1.1 / VKS 3.7.0 / istio.kubernetes.vmware.com.1.30.0-vmware.1-vks.1
# --------------------------------------------------------------------------------------------------
# Goal:
#   - Use Kubernetes Gateway API (GatewayClass, Gateway, HTTPRoute) for application ingress.
#   - Let Istio provision the gateway proxy Service and Deployment when a Gateway is created.
#   - Do NOT install the legacy/preconfigured Istio ingress or egress gateways.
#   - Keep Ambient Mesh and mesh-wide STRICT mTLS disabled for initial evaluation.
#   - Retain useful access logging, Prometheus metrics and a redundant Istio control plane.
#
# Prerequisites (not configured by this file):
#   - Compatible Gateway API CRDs in the VKS workload cluster (check before installing/updating).
#   - An Istio-managed GatewayClass (usually named "istio") after the add-on is ready.
#   - A working Service type LoadBalancer implementation to assign an IP to the Gateway proxy.
#   - A Gateway and HTTPRoute created separately in the VKS workload cluster.
#
# Note: enableGatewayAPIInference refers to the Gateway API Inference Extension,
#       not standard Gateway / HTTPRoute support.
# --------------------------------------------------------------------------------------------------

istio:
  # 1. Standard sidecar model; no Ambient Mesh / ztunnel for this PoC.
  ambientMode:
    enabled: false
    ztunnel:
      resources:
        requests:
          cpu: 200m
          memory: 512Mi

  # 2. Standard Gateway API needs no AI inference extension.
  enableGatewayAPIInference: false

  # 3. Do not impose mesh-wide STRICT mTLS on non-mesh PoC backends.
  enableStrictMTLS: false

  # 4. No preconfigured legacy Istio gateways: Gateway API provisions its own proxy.
  gateways:
    egress:
      autoscaling:
        enabled: false
        maxReplicas: 5
        minReplicas: 1
      enabled: false
      namespace: istio-egress
      namespaceLimitRange:
        defaultRequests:
          cpu: 100m
          memory: 128Mi
      priorityClassName: ""
      replicas: 1
      resources:
        limits:
          cpu: 2000m
          memory: 1024Mi
        requests:
          cpu: 100m
          memory: 128Mi

    ingress:
      autoscaling:
        enabled: false
        maxReplicas: 5
        minReplicas: 1
      enabled: false
      namespace: istio-ingress
      namespaceLimitRange:
        defaultRequests:
          cpu: 100m
          memory: 128Mi
      priorityClassName: ""
      replicas: 1
      resources:
        limits:
          cpu: 2000m
          memory: 1024Mi
        requests:
          cpu: 100m
          memory: 128Mi

  # 5. Retain vendor default Istio CNI support (available for later sidecar testing).
  istioCNI:
    enabled: true
    resources:
      requests:
        cpu: 100m
        memory: 100Mi

  # 6. Mesh observability and networking defaults suitable for PoC.
  meshConfig:
    accessLogFile: /dev/stdout
    connectTimeout: 10s
    enableDNSProxy: false
    enablePrometheusMerge: true
    # Without a tracing collector, turning on tracing adds little value to the PoC.
    enableTracing: false
    externalIstiod: false
    # This governs traditional Istio/Kubernetes Ingress handling, not Gateway API enablement.
    ingressControllerMode: STRICT
    ingressSelector: ingressgateway
    meshID: ""
    meshMTLS:
      minProtocolVersion: TLSV1_2
    network: ""
    proxy:
      resources:
        limits:
          cpu: 2000m
          memory: 1024Mi
        requests:
          cpu: 100m
          memory: 128Mi
    trustDomain: cluster.local
    trustDomainAliases: []
    waypoint:
      resources:
        limits:
          cpu: "2"
          memory: 1Gi
        requests:
          cpu: 100m
          memory: 128Mi

  # 7. Dedicated control-plane namespace.
  namespace: istio-system

  # 8. Default container requests within the Istio control-plane namespace.
  namespaceLimitRange:
    defaultRequests:
      cpu: 100m
      memory: 64Mi

  # 9. Redundant istiod control plane, no autoscaler needed for small PoC.
  pilot:
    autoscaling:
      enabled: false
      maxReplicas: 5
      minReplicas: 2
    priorityClassName: ""
    replicas: 2
    resources:
      requests:
        cpu: 500m
        memory: 2048Mi

  # 10. Add-on supporting resources.
  support:
    priorityClassName: ""
    resources:
      requests:
        cpu: 100m
        memory: 64Mi

# Leave blank unless the add-on documentation requires a specific VKS cluster version override.
vks_cluster_version: ""
EOF

echo "Install istio using the saved values file."
vcf addon install create istio \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    --addon-release-name ${ISTIO_RELEASE} \
    --values-config-file "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-api-data-values.yaml" \
    --yes

echo "Wait for the istio ClusterAddon to be created on the Supervisor."
kubectl wait clusteraddon/${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --for=create --timeout=${READY_TIMEOUT}

echo "Wait for istio readiness; stop if the wait times out."
kubectl wait clusteraddon/${CLUSTER_NAME}-istio \
    -n ${CLUSTER_NAMESPACE} --for=condition=Ready --timeout=${READY_TIMEOUT}

echo "Display the add-on status after the readiness check."
vcf addon install list --cluster-name ${CLUSTER_NAME} -n ${CLUSTER_NAMESPACE}

# ------------------------------------------------------------------------------------------------------------
# Create the istio-gateway namespace.
# Create the Istio Gateway API resource.
# ------------------------------------------------------------------------------------------------------------

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Checking whether Kubernetes recognizes the Gateway resource type."

echo "Verify the Gateway CRD is installed."
kubectl get crd gateways.gateway.networking.k8s.io

echo "Verify the GatewayClass CRD is installed."
kubectl get crd gatewayclasses.gateway.networking.k8s.io

echo "Verify the HTTPRoute CRD is installed."
kubectl get crd httproutes.gateway.networking.k8s.io

echo "Create namespace if it does not exist."
kubectl create namespace ${GATEWAY_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create the application namespace with privileged Pod Security, auditing and warnings enforcement.
cat << EOF > "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-namespace.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: ${GATEWAY_NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF
kubectl apply -f "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-namespace.yaml"

echo "Create the wildcard TLS Secret."
kubectl create secret tls platformlab-wildcard-tls \
    --cert="${SERVER_CERTIFICATE_CHAIN_PATH}" --key="${SERVER_PRIVATE_KEY_PATH}" \
    --namespace=${GATEWAY_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# This allows Assembly, Mongo Express, and future applications to share one Gateway, one Envoy LoadBalancer IP, 
# and one HTTPS listener, while each application manages its own HTTPRoute.

echo "Create a shared Istio Gateway API resource with HTTP and HTTPS."
cat << EOF > "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-resource.yaml"
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: istio
  # Request a specific LoadBalancer IP address
  addresses:
    - type: IPAddress
      value: ${ENVOY_LB_IP}
  listeners:
    # HTTP listener
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    # HTTPS listener with wildcard TLS certificate
    - name: https
      hostname: "*.platformlab.vcf"
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: platformlab-wildcard-tls
      allowedRoutes:
        namespaces:
          from: All
EOF

echo "Apply the Istio Gateway API resource."
kubectl apply -f "${DEPLOYMENT_FILES}/${GATEWAY_NAMESPACE}-resource.yaml"

echo "Wait for the Gateway to be programmed before displaying its resources."
kubectl wait gateways.gateway.networking.k8s.io/${GATEWAY_NAME} \
    -n ${GATEWAY_NAMESPACE} --for=condition=Programmed --timeout=${READY_TIMEOUT}

echo "Verify the Istio Gateway API resource, status, and assigned address."
kubectl get gateway -n ${GATEWAY_NAMESPACE}

echo "Verify the Envoy gateway Deployment, replicas, and availability."
kubectl get deployments -n ${GATEWAY_NAMESPACE}

echo "Verify the Envoy gateway pods and their running status."
kubectl get pods -n ${GATEWAY_NAMESPACE}

echo "Verify the gateway Service, LoadBalancer type, ports, and external IP."
kubectl get svc -n ${GATEWAY_NAMESPACE}

echo "Retrieve the Istio Gateway LoadBalancer IP address."
ENVOY_LB_IP=$(kubectl get svc ${GATEWAY_NAME}-istio -n ${GATEWAY_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Istio Gateway LoadBalancer IP: ${ENVOY_LB_IP}"

