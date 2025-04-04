output "talosconfig" {
  value     = yamlencode(data.talos_client_configuration.talos_config.talos_config)
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "machineconfig_control_plane" {
  value     = yamlencode(data.talos_machine_configuration.machineconfig_control_plane)
  sensitive = true
}

output "machineconfig_worker_01" {
  value     = yamlencode(data.talos_machine_configuration.machineconfig_worker_01)
  sensitive = true
}

output "machineconfig_worker_02" {
  value     = yamlencode(data.talos_machine_configuration.machineconfig_worker_02)
  sensitive = true
}

output "control_plane_ip" {
  value = var.talos_control_plane_ip_addr
}

output "worker_ips" {
  value = [var.talos_worker_01_ip_addr, var.talos_worker_02_ip_addr]
}