resource "talos_machine_secrets" "machine_secrets" {
  depends_on    = [proxmox_virtual_environment_vm.talos_control_plane]
  talos_version = var.talos_os_version
}

# ********************************************
# Talos Control Plane Node Configuration
# ********************************************

data "talos_client_configuration" "talos_config" {
  depends_on           = [proxmox_virtual_environment_vm.talos_control_plane]
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  nodes                = [var.talos_control_plane_ip_addr]
}

data "talos_machine_configuration" "machineconfig_control_plane" {
  depends_on       = [proxmox_virtual_environment_vm.talos_control_plane]
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
# Talos Machine Bootstrap
# ********************************************

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [talos_machine_configuration_apply.control_plane_config_apply,
    talos_machine_configuration_apply.worker_01_config_apply,
  talos_machine_configuration_apply.worker_02_config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_control_plane_ip_addr
}

# ********************************************
# Talos Cluster Health Check
# ********************************************

data "talos_cluster_health" "health" {
  depends_on             = [talos_machine_bootstrap.bootstrap]
  client_configuration   = talos_machine_secrets.machine_secrets.client_configuration
  control_plane_nodes    = [var.talos_control_plane_ip_addr]
  worker_nodes           = [var.talos_worker_01_ip_addr, var.talos_worker_02_ip_addr]
  endpoints              = [var.talos_control_plane_ip_addr]
  skip_kubernetes_checks = var.talos_cluster_health_skip_kubernetes_checks

  timeouts = {
    read = var.talos_cluster_health_timeout
  }
}

# ********************************************
# Talos Cluster Kubeconfig
# ********************************************

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on                   = [data.talos_cluster_health.health]
  client_configuration         = talos_machine_secrets.machine_secrets.client_configuration
  certificate_renewal_duration = var.kubeconfig_certificate_renewal_duration
  node                         = var.talos_control_plane_ip_addr
}
