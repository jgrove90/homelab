resource "talos_machine_secrets" "machine_secrets" {
  depends_on = [proxmox_virtual_environment_vm.talos_control_plane]  # Wait until Proxmox VM is created
  talos_version = var.talos_os_version
}

# ********************************************
# Talos Control Plane Node Configuration
# ********************************************

data "talos_client_configuration" "talos_config" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_control_plane]
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  nodes            = [var.talos_control_plane_ip_addr]
}

data "talos_machine_configuration" "machineconfig_control_plane" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_control_plane]
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_control_plane_ip_addr}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  talos_version    = var.talos_os_version
  config_patches = [file("${path.module}/patch/global.yaml"),
                    file("${path.module}/patch/control-plane.yaml")]
}

resource "talos_machine_configuration_apply" "control_plane_config_apply" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_control_plane]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_control_plane.machine_configuration
  count                       = 1
  node                        = var.talos_control_plane_ip_addr
}

# ********************************************
# Talos Machine Bootstrap
# ********************************************

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.control_plane_config_apply,
                          talos_machine_configuration_apply.worker_01_config_apply, 
                          talos_machine_configuration_apply.worker_02_config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_control_plane_ip_addr
}

# ********************************************
# Talos Worker Node 01 Configuration
# ********************************************

data "talos_machine_configuration" "machineconfig_worker_01" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_control_plane_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  config_patches = [file("${path.module}/patch/global.yaml"),
                    file("${path.module}/patch/worker-01.yaml")]
}

resource "talos_machine_configuration_apply" "worker_01_config_apply" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_worker_01]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker_01.machine_configuration
  count                       = 1
  node                        = var.talos_worker_01_ip_addr
}

# ********************************************
# Talos Worker Node 02 Configuration
# ********************************************

data "talos_machine_configuration" "machineconfig_worker_02" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_control_plane_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  config_patches = [file("${path.module}/patch/global.yaml"),
                  file("${path.module}/patch/worker-02.yaml")]
}

resource "talos_machine_configuration_apply" "worker_02_config_apply" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_worker_02]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker_02.machine_configuration
  count                       = 1
  node                        = var.talos_worker_02_ip_addr
}

# ********************************************
# Talos Cluster Health Check
# ********************************************

# data "talos_cluster_health" "health" {
#   depends_on           = [talos_machine_bootstrap.bootstrap]
#   client_configuration = data.talos_client_configuration.talos_config.client_configuration
#   control_plane_nodes  = [var.talos_control_plane_ip_addr]
#   worker_nodes         = [var.talos_worker_01_ip_addr, var.talos_worker_02_ip_addr]
#   endpoints            = ["https://${var.talos_control_plane_ip_addr}:6443"]

# }
# ********************************************
# Talos Cluster Kubeconfig
# ********************************************

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap] # data.talos_cluster_health.health
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_control_plane_ip_addr
}

# resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_intel" {
#   content_type            = "iso"
#   datastore_id            = "local"
#   node_name               = "severen"

#   file_name               = "talos-${var.talos_os_version}-nocloud-amd64.img"
#   url                     = "https://factory.talos.dev/image/d3dc673627e9b94c6cd4122289aa52c2484cddb31017ae21b75309846e257d30/${var.talos_os_version}/nocloud-amd64.raw.gz"
#   decompression_algorithm = "gz"
#   overwrite               = false
# }

# resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_amd" {
#   content_type            = "iso"
#   datastore_id            = "local"
#   node_name               = "severen"

#   file_name               = "talos-${var.talos_os_version}-nocloud-amd64.img"
#   url                     = "https://factory.talos.dev/image/ef909f816be835a6236a401377846307a921533d6b218c2d8e95c6d9013ede06/${var.talos_os_version}/nocloud-amd64.raw.gz"
#   decompression_algorithm = "gz"
#   overwrite               = false
# }


# ********************************************
# Talos OS Image Factory Schematic Intel
# ********************************************

# data "talos_image_factory_extensions_versions" "system_extensions_intel" {
#   talos_version = var.talos_os_version
#   filters = {
#     names = [
#       "qemu-guest-agent",
#       "i915"
#     ]
#   }
# }

# resource "talos_image_factory_schematic" "talos_image_intel" {
#   schematic = yamlencode(
#     {
#       customization = {
#         systemExtensions = {
#           officialExtensions = data.talos_image_factory_extensions_versions.system_extensions_intel.extensions_info.*.name
#         }
#       }
#     }
#   )
# }

# resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_intel" {
#   depends_on   = [talos_image_factory_schematic.talos_image_intel]
#   content_type = "iso"
#   datastore_id = "local"
#   node_name    = "severen"

#   file_name               = "talos-${var.talos_os_version}-intel-nocloud-amd64.img"
#   url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.talos_image_intel.id}/${var.talos_os_version}/nocloud-amd64.raw.gz"
#   decompression_algorithm = "gz"
#   overwrite               = true
#   verify = false
# }

# ********************************************
# Talos OS Image Factory Schematic AMD
# ********************************************

# data "talos_image_factory_extensions_versions" "system_extensions_amd" {
#   talos_version = var.talos_os_version
#   filters = {
#     names = [
#       "qemu-guest-agent",
#       "amdgpu"
#     ]
#   }
# }

# resource "talos_image_factory_schematic" "talos_image_amd" {
#   schematic = yamlencode(
#     {
#       customization = {
#         systemExtensions = {
#           officialExtensions = data.talos_image_factory_extensions_versions.system_extensions_amd.extensions_info.*.name
#         }
#       }
#     }
#   )
# }

# resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_amd" {
#   depends_on   = [talos_image_factory_schematic.talos_image_amd]
#   content_type = "iso"
#   datastore_id = "local"
#   node_name    = "imre"

#   file_name               = "talos-${var.talos_os_version}-amd-nocloud-amd64.img"
#   url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.talos_image_intel.id}/${var.talos_os_version}/nocloud-amd64.raw.gz"
#   decompression_algorithm = "gz"
#   overwrite               = true
#   verify = false
# }