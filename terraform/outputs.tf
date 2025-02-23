output "talosconfig" {
  value     = yamlencode(data.talos_client_configuration.talos_config.talos_config)
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "client_configuration" {
  value = yamlencode(talos_machine_secrets.machine_secrets.client_configuration)
  sensitive = true
}

output "machineconfig_control_plane" {
  value     = yamlencode(data.talos_machine_configuration.machineconfig_control_plane)
  sensitive = true
}