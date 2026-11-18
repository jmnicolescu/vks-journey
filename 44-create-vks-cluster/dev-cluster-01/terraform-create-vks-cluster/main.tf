#----------------+--------------------------------------------------------------+
# Script Name    | main.tf                                                      |
# Updated        | 2026-11-15                                                   |
# Version        | 1.6                                                          |
# VCF Version    | 9.1.1.0-545627-2026-09                                       |
# Description    | Create a VKS Cluster, wait for availability and save YAML.   |
#----------------+--------------------------------------------------------------+

#----------------+--------------------------------------------------------------+
# Requirement    | Details                                                      |
#----------------+--------------------------------------------------------------+
# Runtime        | Terraform >= 1.5.0; Kubernetes ~> 3.0; local ~> 2.5.         |
# Inputs         | Deployment settings in terraform.tfvars.                     |
# Access         | Authenticated Supervisor kubeconfig and Cluster permissions. |
# Infrastructure | Existing namespace, VM/storage classes and VKS ClusterClass. |
# Behavior       | Waits for Cluster availability and Cluster deletion.        |
#----------------+--------------------------------------------------------------+

locals {
  topology_variables = [
    { name = "vmClass", value = var.vm_class },
    { name = "storageClass", value = var.storage_class },
    {
      name = "bootstrapAddons"
      value = {
        cniRef = {
          name      = "antrea"
          namespace = "vmware-system-vks-public"
        }
      }
    },
    {
      name = "kubernetes"
      value = {
        certificateRotation = {
          enabled                 = true
          renewalDaysBeforeExpiry = 90
        }
        security = {
          podSecurityStandard = {
            # Match the Supervisor default to preserve the dynamic object shape.
            deactivated    = false
            audit          = "restricted"
            auditVersion   = "latest"
            enforce        = "privileged"
            enforceVersion = "latest"
            warn           = "privileged"
            warnVersion    = "latest"
          }
        }
      }
    }
  ]

  trust_variables = length(var.additional_trusted_cas) == 0 ? [] : [
    {
      name = "osConfiguration"
      value = {
        trust = {
          additionalTrustedCAs = [
            for ca in var.additional_trusted_cas : {
              caCert = {
                secretRef = {
                  name = ca.secret_name
                  key  = ca.key
                }
              }
            }
          ]
        }
      }
    }
  ]

  cluster_manifest = {
    apiVersion = "cluster.x-k8s.io/v1beta2"
    kind       = "Cluster"
    metadata = {
      name      = var.cluster_name
      namespace = var.namespace
    }
    spec = {
      clusterNetwork = {
        pods          = { cidrBlocks = var.pod_cidrs }
        services      = { cidrBlocks = var.service_cidrs }
        serviceDomain = "cluster.local"
      }
      topology = {
        classRef = {
          name      = var.cluster_class
          namespace = var.cluster_class_namespace
        }
        version   = var.kubernetes_version
        variables = concat(local.topology_variables, local.trust_variables)
        controlPlane = {
          replicas = var.control_plane_count
          metadata = {
            annotations = {
              "run.tanzu.vmware.com/resolve-os-image" = "os-name=photon"
            }
          }
        }
        workers = {
          machineDeployments = [{
            class    = "node-pool"
            name     = "${var.cluster_name}-np01"
            replicas = var.worker_count
            metadata = {
              annotations = {
                "run.tanzu.vmware.com/resolve-os-image" = "os-name=photon"
              }
            }
            variables = {
              overrides = [{
                name = "volumes"
                value = [{
                  name         = "vol-containerd"
                  mountPath    = "/var/lib/containerd"
                  storageClass = var.storage_class
                  capacity     = var.containerd_volume_capacity
                }]
              }]
            }
          }]
        }
      }
    }
  }
}

# Create and manage the VKS Cluster in the Supervisor namespace.
resource "kubernetes_manifest" "cluster" {
  manifest = local.cluster_manifest

  # Supervisor adds variable defaults and resolves the VKS release identifier.
  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "spec.topology.variables",
    "spec.topology.version",
  ]

  # Wait for the Cluster to report overall availability.
  wait {
    condition {
      type   = "Available"
      status = "True"
    }
  }

  timeouts {
    create = var.cluster_wait_timeout
    update = var.cluster_wait_timeout
    delete = var.cluster_wait_timeout
  }

  field_manager {
    name            = "terraform-vks-cluster"
    force_conflicts = false
  }
}

# Save the desired Cluster manifest as a reusable local YAML file.
resource "local_file" "cluster_manifest" {
  content              = yamlencode(local.cluster_manifest)
  filename             = "${path.root}/deployment-files/create-${var.cluster_name}.yaml"
  file_permission      = "0600"
  directory_permission = "0700"
}

