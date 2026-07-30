locals {
  talosconfig_file_path = pathexpand(coalesce(var.talosconfig_output_path, "~/.talos/${var.cluster_name}/talosconfig"))
  kubeconfig_file_path  = pathexpand(coalesce(var.kubeconfig_output_path, "~/.kube/${var.cluster_name}-config"))
  sops_age_key_file     = pathexpand(var.sops_age_key_file_path)
}

resource "local_sensitive_file" "talosconfig" {
  content              = data.talos_client_configuration.talos_config.talos_config
  filename             = local.talosconfig_file_path
  directory_permission = "0700"
  file_permission      = "0600"
}

resource "local_sensitive_file" "kubeconfig" {
  content              = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename             = local.kubeconfig_file_path
  directory_permission = "0700"
  file_permission      = "0600"
}

resource "terraform_data" "flux_sops_age_secret" {
  count = var.reconcile_flux_sops_age_secret ? 1 : 0

  triggers_replace = {
    age_key_checksum = filesha256(local.sops_age_key_file)
    kubeconfig_path  = local.kubeconfig_file_path
    namespace        = var.flux_sops_secret_namespace
    secret_name      = var.flux_sops_secret_name
  }

  lifecycle {
    precondition {
      condition     = fileexists(local.sops_age_key_file)
      error_message = "The Flux Age key file was not found at ${local.sops_age_key_file}. Update var.sops_age_key_file_path or create the key before applying Terraform."
    }
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      kubectl --kubeconfig="${local.kubeconfig_file_path}" create namespace "${var.flux_sops_secret_namespace}" --dry-run=client -o yaml | kubectl --kubeconfig="${local.kubeconfig_file_path}" apply -f -
      kubectl --kubeconfig="${local.kubeconfig_file_path}" create secret generic "${var.flux_sops_secret_name}" \
        --namespace="${var.flux_sops_secret_namespace}" \
        --from-file=age.agekey="${local.sops_age_key_file}" \
        --dry-run=client -o yaml | kubectl --kubeconfig="${local.kubeconfig_file_path}" apply -f -
    EOT
  }

  depends_on = [
    data.talos_cluster_health.health,
    local_sensitive_file.kubeconfig,
    talos_cluster_kubeconfig.kubeconfig,
  ]
}