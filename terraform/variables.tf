variable "talos_os_version" {
  description = "The version of Talos Linux to use"
  type        = string
  default     = "1.9.4"
}

variable "proxmox_endpoint" {
  description = "The endpoint URL for the Proxmox server"
  type        = string
  default     = "https://192.168.1.101:8006"
}

variable "proxmox_api_token" {
  description = "The Proxmox API token, intended to be provided via TF_VAR_proxmox_api_token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  default     = "homelab"
}

variable "default_gateway" {
  description = "The gateway for the network"
  type        = string
  default     = "192.168.1.1"
}

variable "talos_control_plane_ip_addr" {
  description = "The IP address of the control plane node (severen)"
  type        = string
  default     = "192.168.1.19"
}

variable "talos_worker_01_ip_addr" {
  description = "The IP address of the first worker node (severen)"
  type        = string
  default     = "192.168.1.20"
}

variable "talos_worker_02_ip_addr" {
  description = "The IP address of the second worker node (imre)"
  type        = string
  default     = "192.168.1.15"
}

variable "talosconfig_output_path" {
  description = "Optional override for the generated talosconfig path on the machine running Terraform"
  type        = string
  default     = "~/.talos/talosconfig"
}

variable "kubeconfig_output_path" {
  description = "Optional override for the generated kubeconfig path on the machine running Terraform"
  type        = string
  default     = "~/.talos/kubeconfig"
}

variable "kubeconfig_certificate_renewal_duration" {
  description = "How far ahead of expiry Terraform should renew the generated kubeconfig certificate"
  type        = string
  default     = "8760h"
}

variable "talos_cluster_health_timeout" {
  description = "How long Terraform should wait for the Talos cluster health check"
  type        = string
  default     = "10m"
}

variable "talos_cluster_health_skip_kubernetes_checks" {
  description = "Skip Kubernetes component checks during the Talos cluster health gate"
  type        = bool
  default     = false
}

variable "sops_age_key_file_path" {
  description = "Path to the local Age private key that Flux should use for SOPS decryption"
  type        = string
  default     = "~/.sops/age.agekey"
}

variable "reconcile_flux_sops_age_secret" {
  description = "When true, Terraform will apply or update the Flux sops-age secret using kubectl after kubeconfig generation"
  type        = bool
  default     = true
}

variable "flux_sops_secret_namespace" {
  description = "Namespace that contains the Flux SOPS decryption secret"
  type        = string
  default     = "flux-system"
}

variable "flux_sops_secret_name" {
  description = "Name of the Flux SOPS decryption secret"
  type        = string
  default     = "sops-age"
}