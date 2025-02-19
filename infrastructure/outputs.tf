output "talosconfig" {
  value     = data.talos_client_configuration.talos_config.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

# output "talos_image_schematic_id_intel" {
#   value = talos_image_factory_schematic.talos_image_intel.id
# }

# output "talos_image_schematic_id" {
#   value = talos_image_factory_schematic.talos_image_amd.id
# }