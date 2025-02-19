resource "proxmox_virtual_environment_vm" "talos_control_plane" {
  #depends_on  = [proxmox_virtual_environment_download_file.talos_nocloud_image_intel]
  name        = "talos-control-plane"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "severen"
  on_boot     = true

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    mac_address = "bc:24:11:ff:67:76"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = "local:iso/talos_linux_v1.9.4_intel.iso"
    file_format  = "raw"
    interface    = "virtio0"
    size         = 20
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${var.talos_control_plane_ip_addr}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker_01" {
  depends_on  = [talos_machine_bootstrap.bootstrap]
  name        = "talos-worker-01"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "severen"
  on_boot     = true

  cpu {
    cores = 10
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 28672 # 28 GiB
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    mac_address = "bc:24:11:4f:d0:b9"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = "local:iso/talos_linux_v1.9.4_intel.iso"
    file_format  = "raw"
    interface    = "virtio0"
    size         = 20
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${var.talos_worker_01_ip_addr}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker_02" {
  depends_on  = [talos_machine_bootstrap.bootstrap]
  name        = "talos-worker-02"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "imre"
  on_boot     = true

  cpu {
    cores = 16
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 32768 # 28 GiB
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    mac_address = "bc:24:11:75:98:ba"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = "local:iso/talos_linux_v1.9.4_amd.iso"
    file_format  = "raw"
    interface    = "virtio0"
    size         = 20
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${var.talos_worker_02_ip_addr}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}
