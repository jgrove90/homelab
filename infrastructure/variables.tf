variable "talos_os_version" {
  description = "The version of Talos Linux to use"
  type        = string
  default     = "1.9.4"
}

variable "proxmox_endpoint" {
  description = "The endpoint URL for the Proxmox server"
  type        = string
  default     = "https://192.168.0.10:8006"
}

variable "proxmox_api_key" {
  description = "The API token for the Proxmox server. Located in .env file"
  type        = string
  sensitive   = true
}

variable "proxmox_username" {
  description = "Proxmox username located in .env file"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox password located in .env file"
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
  default     = "192.168.0.1"
}

variable "talos_control_plane_ip_addr" {
  description = "The IP address of the control plane node"
  type        = string
  default     = "192.168.0.41"
}

variable "talos_worker_01_ip_addr" {
  description = "The IP address of the first worker node"
  type        = string
  default     = "192.168.0.42"
}

variable "talos_worker_02_ip_addr" {
  description = "The IP address of the second worker node"
  type        = string
  default     = "192.168.0.35"
}