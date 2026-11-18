#!/bin/bash
#-------------+-------------------------------------------------------------------+
# Script Name | 10-install-contour-addon-vcf-cli.sh                               |
# Updated     | 2026-11-17                                                        |
# Version     | 1.25                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                            |
# Description | Install cert-manager and contour with static Gateway API routing. |
#-------------+-------------------------------------------------------------------+

#-------------+-------------------------------------------------------------------+
# Requirement | Details                                                           |
#-------------+-------------------------------------------------------------------+
# Tools       | VCF CLI 9.1.1, kubectl, jq and standard shell utilities.          |
# Access      | Existing authenticated Supervisor and workload contexts.          |
# Inputs      | Set context, cluster, Supervisor namespace and add-on releases.   |
# Permissions | Install add-ons; manage TLS Secrets, Gateway and GatewayClass.    |
# Network     | API access, package image pulls and LoadBalancer provisioning.    |
# Files       | Write access to deployment-files beside the script.               |
# Behavior    | Changes context; stops when a command fails.                      |
#-------------+-------------------------------------------------------------------+
# set -eo pipefail

CONTEXT_NAME=supervisor
CLUSTER_NAMESPACE=qa-namespace
CLUSTER_NAME=qa-cluster-02

CERT_MANAGER_RELEASE=cert-manager.kubernetes.vmware.com.1.20.2-vmware.1-vks.1
CONTOUR_RELEASE=contour.kubernetes.vmware.com.1.33.4-vmware.1-vks.1

READY_TIMEOUT=10m
# Static LoadBalancer IP request — subject to VKS LoadBalancer provider support
# The package maps this request to Service spec.loadBalancerIP; verify the assigned address.
ENVOY_LB_IP=10.55.16.103

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
DEPLOYMENT_FILES=${SCRIPT_DIR}/deployment-files
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates
mkdir -p "${DEPLOYMENT_FILES}"

APP_FQDN=wildcard.platformlab.vcf
SERVER_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${APP_FQDN}.key
SERVER_CERTIFICATE_CHAIN_PATH=${CERTIFICATES_DIR}/${APP_FQDN}.cer.plusCA

GATEWAY_NAME=contour-gateway
GATEWAY_NAMESPACE=tanzu-system-ingress

# ------------------------------------------------------------------------------------------------------------
# Install Cert Manager Addon using VCF CLI
#
# NAMESPACE           vmware-system-vks-public
# ADDONNAME           cert-manager
# VERSION             1.20.2+vmware.1-vks.1
# ADDON-RELEASE-NAME  cert-manager.kubernetes.vmware.com.1.20.2-vmware.1-vks.1
# PACKAGE             cert-manager.kubernetes.vmware.com/1.20.2+vmware.1-vks.1  
# ------------------------------------------------------------------------------------------------------------

echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}
# kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Check the pinned cert-manager release before installing either add-on."
vcf addon available-releases get ${CERT_MANAGER_RELEASE}

echo "Check the pinned contour release before installing either add-on."
vcf addon available-releases get ${CONTOUR_RELEASE}

echo "Export the values from the exact cert-manager release to be installed."
vcf addon available-releases get ${CERT_MANAGER_RELEASE} \
    --values-config-file-output "${DEPLOYMENT_FILES}/cert-manager-default-data-values.yaml"

# ---------------------------------------+--------------------------+--------------------------------------------------------+
# Recommended cert-manager settings                                                                                          |
# ---------------------------------------+--------------------------+--------------------------------------------------------+
# Setting                                | Recommended              | Purpose                                                |
# ---------------------------------------+--------------------------+--------------------------------------------------------+
# certManager.pspNames                   | vmware-system-privileged | Retain VMware package security configuration.          |
# controller.enableGatewayAPI            | true                     | Enable Gateway API certificate management.             |
# controller.enableGatewayAPIListenerSet | false                    | Disable experimental ListenerSet integration.          |
# deploymentMode.resources.requests.cpu  | 10m                      | Retain default CPU request for deployment components.  |
# deploymentMode.resources.requests.memory| 64Mi                    | Retain default memory request.                         |
# issuers                                | []                       | Configure certificate issuers separately.              |
# kubernetes_distribution                | ""                       | Use automatic distribution detection.                  |
# kubernetes_version                     | ""                       | Use automatic Kubernetes version detection.            |
# namespace                              | cert-manager             | Deploy cert-manager in its dedicated namespace.        |
# nsLimitRange.defaultRequests.cpu       | 10m                      | Set default namespace CPU requests.                    |
# nsLimitRange.defaultRequests.memory    | 64Mi                     | Set default namespace memory requests.                 |
# priorityClassName                      | ""                       | Use default Kubernetes scheduling priority.            |
# ---------------------------------------+--------------------------+--------------------------------------------------------+

echo "Write the cert-manager data values file."
cat << EOF > "${DEPLOYMENT_FILES}/cert-manager-data-values.yaml"
certManager:
  pspNames:
    - vmware-system-privileged
# Enable standard Gateway API certificate integration.
controller:
  enableGatewayAPI: true
  enableGatewayAPIListenerSet: false
# Retain VMware default deployment resource requests.
deploymentMode:
  resources:
    requests:
      cpu: 10m
      memory: 64Mi
# Certificate issuers will be configured separately.
issuers: []
# Use package defaults for Kubernetes distribution and version.
kubernetes_distribution: ""
kubernetes_version: ""
# cert-manager installation namespace.
namespace: cert-manager
# Default namespace resource requests.
nsLimitRange:
  defaultRequests:
    cpu: 10m
    memory: 64Mi
# Use default Kubernetes scheduling priority.
priorityClassName: ""
EOF

echo "Check whether cert-manager is already installed for this cluster."
EXISTING_ADDON=$(kubectl --context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE} get addoninstall cert-manager-${CLUSTER_NAME} \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found -o name)

# Create a new installation or update its existing configuration on reruns.
ADDON_ACTION=create
RELEASE_ARGS=(--addon-release-name ${CERT_MANAGER_RELEASE})
if [ -n "${EXISTING_ADDON}" ]; then
    ADDON_ACTION=update
    RELEASE_ARGS=()
fi

echo "${ADDON_ACTION} cert-manager using the saved values file."
vcf addon install ${ADDON_ACTION} cert-manager \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    "${RELEASE_ARGS[@]}" \
    --values-config-file "${DEPLOYMENT_FILES}/cert-manager-data-values.yaml" \
    --yes

echo "Wait for the cert-manager ClusterAddon to be created on the Supervisor."
kubectl wait clusteraddon/${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --for=create --timeout=${READY_TIMEOUT}

echo "Wait for cert-manager readiness; stop if the wait times out."
kubectl wait clusteraddon/${CLUSTER_NAME}-cert-manager \
    -n ${CLUSTER_NAMESPACE} --for=condition=Ready --timeout=${READY_TIMEOUT}

echo "Display the add-on status after the readiness check."
vcf addon install list --cluster-name ${CLUSTER_NAME} -n ${CLUSTER_NAMESPACE}

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}
# kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "------------------------------------------------------------------------------------------------------------"
echo "Display cert-manager resources after the readiness checks."
kubectl get all -n cert-manager
echo "------------------------------------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------------------------------------
# Install Contour Addon using VCF CLI
# 
# NAMESPACE             vmware-system-vks-public
# ADDONNAME             contour
# VERSION               1.33.4+vmware.1-vks.1
# ADDON-RELEASE-NAME    contour.kubernetes.vmware.com.1.33.4-vmware.1-vks.1
# PACKAGE               contour.kubernetes.vmware.com/1.33.4+vmware.1-vks.1                                              
# ------------------------------------------------------------------------------------------------------------
 
echo "Refresh Supervisor authentication."
vcf context refresh ${CONTEXT_NAME} >/dev/null 2>&1

echo "Select the target Supervisor namespace."
vcf context use ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}
# kubectl config use-context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE}

echo "Check the pinned Contour release before installation."
vcf addon available-releases get ${CONTOUR_RELEASE}

echo "Export the values from the exact contour release to be installed."
vcf addon available-releases get ${CONTOUR_RELEASE} \
    --values-config-file-output "${DEPLOYMENT_FILES}/contour-default-data-values.yaml"

# -----------------------------------------+--------------+-----------------------------------------------------------------------+
# Recommended Contour settings                                                                                                    |
# -----------------------------------------+--------------+-----------------------------------------------------------------------+
# Setting                                  | Recommended  | Purpose                                                               |
# -----------------------------------------+--------------+-----------------------------------------------------------------------+
# certificates.caDuration                  | 8760h        | Internal CA certificate valid for one year.                           |
# certificates.caRenewBefore               | 720h         | Renew the CA 30 days before expiry.                                   |
# certificates.leafDuration                | 720h         | Internal component certificates valid for 30 days.                    |
# certificates.leafRenewBefore             | 360h         | Renew leaf certificates 15 days before expiry.                        |
# contour.disableGRPCRoutes                | true         | Disable GRPCRoute processing; use HTTPRoute for the POC.              |
# contour.listenIPFamily                   | IPv4         | Use IPv4 networking for the controller.                               |
# contour.logLevel                         | info         | Enable standard operational logging.                                  |
# contour.replicas                         | 2            | Run two Contour controller replicas.                                  |
# contour.useProxyProtocol                 | false        | Disable PROXY protocol unless required by the load balancer.          |
# enableSupervisorServiceRbac              | false        | Retain the workload-cluster add-on default.                           |
# envoy.hostNetwork                        | false        | Use standard Kubernetes Pod networking.                               |
# envoy.hostPorts.enable                   | false        | Avoid binding HTTP/HTTPS directly to node ports.                      |
# envoy.listenIPFamily                     | IPv4         | Use IPv4 networking for Envoy.                                        |
# envoy.logLevel                           | info         | Enable standard Envoy logging.                                        |
# envoy.service.type                       | LoadBalancer | Expose Envoy through the VKS load-balancing provider.                 |
# envoy.service.externalTrafficPolicy      | Cluster      | Allow external traffic to reach Envoy endpoints across nodes.         |
# envoy.service.loadBalancerIP             | 10.55.16.103 | Request the configured static VIP from the provider.                             |
# envoy.service.loadBalancerTLSTermination | false        | Terminate application HTTPS in Envoy.                                 |
# envoy.workload.type                      | Deployment   | Run Envoy as a scalable Deployment instead of a DaemonSet.            |
# envoy.workload.replicas                  | 2            | Run two Envoy proxies for availability.                               |
# envoy.terminationGracePeriodSeconds      | 300          | Allow graceful Envoy shutdown.                                        |
# infrastructure_provider                  | vsphere      | Use the vSphere infrastructure profile.                               |
# namespace                                | tanzu-system-ingress | Install Contour and Envoy in a dedicated namespace.           |
# priorityClassName                        | ""           | Use default Kubernetes scheduling priority.                           |
# -----------------------------------------+--------------+-----------------------------------------------------------------------+

echo "Request LoadBalancer IP ${ENVOY_LB_IP} through envoy.service.loadBalancerIP."

cat << EOF > "${DEPLOYMENT_FILES}/contour-data-values.yaml"
# --------------------------------------------------------------------------------------------------
# VCF 9.1.1 / VKS 3.7.0 / contour.kubernetes.vmware.com.1.33.4-vmware.1-vks.1 
# --------------------------------------------------------------------------------------------------
# Goal:
#   - Use Kubernetes Gateway API (GatewayClass, Gateway, HTTPRoute) for HTTP/HTTPS application routing.
#   - Do NOT use traditional Kubernetes Ingress or Contour HTTPProxy resources.
#   - Deploy two Contour controller replicas and two Envoy proxy replicas.
#   - Expose Envoy through a Kubernetes LoadBalancer Service using IPv4 networking.
#   - Terminate application TLS in Envoy using certificates referenced by Gateway listeners.
#   - Retain standard logging and package-managed internal certificates for Contour/Envoy.
#
# Prerequisites (not configured by this file):
#   - Compatible Gateway API CRDs installed in the VKS workload cluster.
#   - cert-manager installed and configured if required for certificate management.
#   - Verify or create a GatewayClass using the Contour controller and supported provisioning mode.
#   - A working VKS LoadBalancer provider (NSX or Avi, as configured) and available IPv4 addresses.
#   - A Gateway and application HTTPRoutes created separately in the workload cluster.
#   - Application-facing TLS Secrets and DNS records configured separately.
# --------------------------------------------------------------------------------------------------

certificates:
  caDuration: 8760h
  caRenewBefore: 720h
  leafDuration: 720h
  leafRenewBefore: 360h

contour:
  configFileContents:
    gateway:
      gatewayRef:
        name: ${GATEWAY_NAME}
        namespace: ${GATEWAY_NAMESPACE}
  disableGRPCRoutes: true
  listenIPFamily: IPv4
  logLevel: info
  pspNames: vmware-system-restricted
  replicas: 2
  resources:
    contour:
      requests:
        cpu: 128m
        memory: 256Mi
  service:
    ipFamilies: []
    ipFamilyPolicy: ""
  useProxyProtocol: false

enableSupervisorServiceRbac: false

envoy:
  bootstrap:
    overloadManager:
      downstreamMaxConnections: 0
      maxHeap: 0
  hostNetwork: false
  hostPorts:
    enable: false
    http: 80
    https: 443
  listenIPFamily: IPv4
  logLevel: info
  pspNames: ""
  service:
    aws:
      LBType: classic
    disableWait: false
    externalTrafficPolicy: Cluster
    ipFamilies: []
    ipFamilyPolicy: ""
    # Request this address from the LoadBalancer provider; allocation must be verified.
    loadBalancerIP: ${ENVOY_LB_IP}
    loadBalancerTLSTermination: false
    nodePorts:
      http: 0
      https: 0
    # Exactly one 'type' field. A later type: "" would override this and could cause NodePort fallback.
    type: LoadBalancer
  terminationGracePeriodSeconds: 300
  workload:
    replicas: 2
    resources:
      envoy:
        requests:
          cpu: 128m
          memory: 256Mi
      envoyInitConfig:
        requests:
          cpu: 128m
          memory: 256Mi
      shutdownManager:
        requests:
          cpu: 10m
          memory: 16Mi
    type: Deployment

infrastructure_provider: vsphere
kubernetes_distribution: ""
kubernetes_version: 0.0.0
namespace: tanzu-system-ingress
nsLimitRange:
  defaultRequests:
    cpu: 128m
    memory: 256Mi
priorityClassName: ""
registry_secret_names:
  - contour-reg-creds
EOF

echo "Check whether contour is already installed for this cluster."
EXISTING_ADDON=$(kubectl --context ${CONTEXT_NAME}:${CLUSTER_NAMESPACE} get addoninstall contour-${CLUSTER_NAME} \
    -n ${CLUSTER_NAMESPACE} --ignore-not-found -o name)

# Create a new installation or update its existing configuration on reruns.
ADDON_ACTION=create
RELEASE_ARGS=(--addon-release-name ${CONTOUR_RELEASE})
if [ -n "${EXISTING_ADDON}" ]; then
    ADDON_ACTION=update
    RELEASE_ARGS=()
fi

echo "${ADDON_ACTION} contour using the saved values file."
vcf addon install ${ADDON_ACTION} contour \
    --cluster-name ${CLUSTER_NAME} \
    --namespace ${CLUSTER_NAMESPACE} \
    "${RELEASE_ARGS[@]}" \
    --values-config-file "${DEPLOYMENT_FILES}/contour-data-values.yaml" \
    --yes

echo "Wait for the contour ClusterAddon to be created on the Supervisor."
kubectl wait clusteraddon/${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --for=create --timeout=${READY_TIMEOUT}

echo "Wait for contour readiness; stop if the wait times out."
kubectl wait clusteraddon/${CLUSTER_NAME}-contour \
    -n ${CLUSTER_NAMESPACE} --for=condition=Ready --timeout=${READY_TIMEOUT}

echo "Display the add-on status after the readiness check."
vcf addon install list --cluster-name ${CLUSTER_NAME} -n ${CLUSTER_NAMESPACE}

# ------------------------------------------------------------------------------------------------------------
# Create Contour Gateway API resource.
# ------------------------------------------------------------------------------------------------------------

echo "Refresh workload cluster authentication and retain error messages."
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1

echo "Select the workload cluster context."
vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}
# kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

echo "Checking whether Kubernetes recognizes the Gateway resource type."

echo "Verify the Gateway CRD is installed."
kubectl get crd gateways.gateway.networking.k8s.io

echo "Verify the GatewayClass CRD is installed."
kubectl get crd gatewayclasses.gateway.networking.k8s.io

echo "Verify the HTTPRoute CRD is installed."
kubectl get crd httproutes.gateway.networking.k8s.io

echo "Wait for the named Envoy service to exist."
kubectl wait service/envoy -n ${GATEWAY_NAMESPACE} --for=create --timeout=${READY_TIMEOUT}

echo "Wait for the requested LoadBalancer IP ${ENVOY_LB_IP}."
kubectl wait service/envoy -n ${GATEWAY_NAMESPACE} \
    --for=jsonpath='{.status.loadBalancer.ingress[0].ip}'=${ENVOY_LB_IP} --timeout=${READY_TIMEOUT}

echo "Create the wildcard TLS Secret."
kubectl create secret tls platformlab-wildcard-tls \
    --cert="${SERVER_CERTIFICATE_CHAIN_PATH}" --key="${SERVER_PRIVATE_KEY_PATH}" \
    --namespace=${GATEWAY_NAMESPACE} --dry-run=client -o yaml | kubectl --context ${CLUSTER_NAME}:${CLUSTER_NAME} apply -f -

# This allows Assembly, Mongo Express, and future applications to share one Gateway, one Envoy LoadBalancer IP, 
# and one HTTPS listener, while each application manages its own HTTPRoute.

echo "Create GatewayClass and Gateway API resource with HTTP and HTTPS."
cat << EOF > "${DEPLOYMENT_FILES}/${GATEWAY_NAME}-resource.yaml"
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: contour
spec:
  controllerName: projectcontour.io/gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: contour
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
          - group: ""
            kind: Secret
            name: platformlab-wildcard-tls
      allowedRoutes:
        namespaces:
          from: All
EOF

echo "Apply the Contour Gateway API resource."
kubectl apply -f "${DEPLOYMENT_FILES}/${GATEWAY_NAME}-resource.yaml"

kubectl get gatewayclass

echo "Wait for the Gateway to be programmed before displaying its resources."
kubectl wait gateways.gateway.networking.k8s.io/${GATEWAY_NAME} \
    -n ${GATEWAY_NAMESPACE} --for=condition=Programmed --timeout=${READY_TIMEOUT}

echo "Verify the Contour Gateway API resource, status, and assigned address."
kubectl get gateway -n ${GATEWAY_NAMESPACE}

echo "Verify the Envoy gateway Deployment, replicas, and availability."
kubectl get deployments -n ${GATEWAY_NAMESPACE}

echo "Verify the Envoy gateway pods and their running status."
kubectl get pods -n ${GATEWAY_NAMESPACE}

echo "Verify the gateway Service, LoadBalancer type, ports, and external IP."
kubectl get svc -n ${GATEWAY_NAMESPACE}

echo "Display Envoy LoadBalancer IP addresses and hostnames."
kubectl get svc envoy -n ${GATEWAY_NAMESPACE} \
    -o custom-columns='NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,HOSTNAME:.status.loadBalancer.ingress[*].hostname'

echo "Displays only the Gateway listener status, including conditions (Accepted, Programmed, ResolvedRefs) and the number of attached routes."
kubectl get gateway ${GATEWAY_NAME} -n ${GATEWAY_NAMESPACE} -o json | jq '.status.listeners'    

echo "Retrieve the Envoy Gateway LoadBalancer IP address."
ASSIGNED_ENVOY_LB_IP=$(kubectl get svc envoy -n ${GATEWAY_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Requested Envoy IP: ${ENVOY_LB_IP}; assigned IP: ${ASSIGNED_ENVOY_LB_IP}"
